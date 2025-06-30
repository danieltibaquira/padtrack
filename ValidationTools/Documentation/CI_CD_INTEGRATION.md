# CI/CD Integration Guide for DigitonePad Validation

This guide explains how to integrate the DigitonePad validation framework into various CI/CD systems.

## Overview

The validation framework provides automated testing across:
- Build system validation
- Protocol compilation checks
- Core Data validation
- Memory profiling
- Dependency verification

## GitHub Actions Integration

### Basic Workflow

Create `.github/workflows/validation.yml`:

```yaml
name: DigitonePad Validation

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  validation:
    runs-on: macos-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '15.1'
        
    - name: Cache Swift packages
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-swift-${{ hashFiles('Package.swift') }}
        restore-keys: |
          ${{ runner.os }}-swift-
          
    - name: Install dependencies
      run: |
        brew install bc jq python3
        
    - name: Run validation
      run: |
        ./ValidationTools/Scripts/run_validation.sh
        
    - name: Generate summary
      run: |
        ./ValidationTools/Scripts/generate_validation_summary.sh
        
    - name: Upload validation reports
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: validation-reports
        path: ValidationTools/Reports/
        retention-days: 30
        
    - name: Comment PR with results
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v6
      with:
        script: |
          const fs = require('fs');
          const path = 'ValidationTools/Reports';
          
          // Find latest summary
          const files = fs.readdirSync(path);
          const summaryFile = files.find(f => f.startsWith('validation_summary_') && f.endsWith('.json'));
          
          if (summaryFile) {
            const summary = JSON.parse(fs.readFileSync(`${path}/${summaryFile}`, 'utf8'));
            
            const comment = `## 🔍 Validation Results
            
            **Overall Status**: ${summary.overall_status === 'passed' ? '✅ PASSED' : '❌ FAILED'}
            **Success Rate**: ${summary.summary.success_rate}%
            
            ### Results by Category
            ${Object.entries(summary.validation_categories).map(([cat, status]) => 
              `- ${cat}: ${status === 'passed' ? '✅' : '❌'} ${status.toUpperCase()}`
            ).join('\n')}
            
            ### Device Compatibility
            ${Object.entries(summary.device_compatibility).map(([device, status]) => 
              `- ${device}: ${status === 'compatible' ? '✅' : '❌'} ${status.toUpperCase()}`
            ).join('\n')}
            `;
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
          }
```

### Advanced Workflow with Matrix Testing

```yaml
name: DigitonePad Validation Matrix

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  validation:
    runs-on: macos-latest
    strategy:
      matrix:
        xcode-version: ['15.0', '15.1', '15.2']
        validation-type: ['build', 'memory', 'core-data']
        
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Setup Xcode ${{ matrix.xcode-version }}
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: ${{ matrix.xcode-version }}
        
    - name: Run specific validation
      run: |
        case "${{ matrix.validation-type }}" in
          "build")
            ./ValidationTools/Scripts/build_verification.sh
            ;;
          "memory")
            ./ValidationTools/Scripts/memory_profiling.sh
            ;;
          "core-data")
            ./ValidationTools/Scripts/core_data_validation.sh
            ;;
        esac
```

## Jenkins Pipeline

### Declarative Pipeline

Create `Jenkinsfile`:

```groovy
pipeline {
    agent {
        label 'macos'
    }
    
    environment {
        XCODE_VERSION = '15.1'
        DEVELOPER_DIR = '/Applications/Xcode_15.1.app/Contents/Developer'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Setup') {
            steps {
                sh '''
                    # Install dependencies
                    brew install bc jq python3 || true
                    
                    # Clean previous builds
                    swift package clean
                    xcodebuild clean
                '''
            }
        }
        
        stage('Validation') {
            parallel {
                stage('Build Verification') {
                    steps {
                        sh './ValidationTools/Scripts/build_verification.sh'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'ValidationTools/Reports/build_verification_*.json', allowEmptyArchive: true
                        }
                    }
                }
                
                stage('Protocol Validation') {
                    steps {
                        sh './ValidationTools/Scripts/protocol_validation.sh'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'ValidationTools/Reports/protocol_validation_*.json', allowEmptyArchive: true
                        }
                    }
                }
                
                stage('Core Data Validation') {
                    steps {
                        sh './ValidationTools/Scripts/core_data_validation.sh'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'ValidationTools/Reports/core_data_validation_*.json', allowEmptyArchive: true
                        }
                    }
                }
                
                stage('Memory Profiling') {
                    steps {
                        sh './ValidationTools/Scripts/memory_profiling.sh'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'ValidationTools/Reports/memory_profile_*.json', allowEmptyArchive: true
                        }
                    }
                }
            }
        }
        
        stage('Summary') {
            steps {
                sh './ValidationTools/Scripts/generate_validation_summary.sh'
                
                publishHTML([
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'ValidationTools/Reports',
                    reportFiles: 'validation_summary_*.md',
                    reportName: 'Validation Summary'
                ])
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'ValidationTools/Reports/**/*', allowEmptyArchive: true
            
            // Send notifications
            script {
                def summary = readJSON file: 'ValidationTools/Reports/validation_summary_*.json'
                def status = summary.overall_status == 'passed' ? 'SUCCESS' : 'FAILURE'
                
                slackSend(
                    channel: '#digitonepad-ci',
                    color: status == 'SUCCESS' ? 'good' : 'danger',
                    message: """
                        DigitonePad Validation ${status}
                        Success Rate: ${summary.summary.success_rate}%
                        Build: ${env.BUILD_URL}
                    """
                )
            }
        }
        
        failure {
            emailext(
                subject: "DigitonePad Validation Failed - Build ${env.BUILD_NUMBER}",
                body: """
                    The DigitonePad validation pipeline has failed.
                    
                    Build: ${env.BUILD_URL}
                    Branch: ${env.BRANCH_NAME}
                    Commit: ${env.GIT_COMMIT}
                    
                    Please check the validation reports for details.
                """,
                to: "${env.CHANGE_AUTHOR_EMAIL}"
            )
        }
    }
}
```

## GitLab CI Integration

Create `.gitlab-ci.yml`:

```yaml
stages:
  - validate
  - report

variables:
  XCODE_VERSION: "15.1"

before_script:
  - export DEVELOPER_DIR="/Applications/Xcode_${XCODE_VERSION}.app/Contents/Developer"
  - brew install bc jq python3 || true

build_validation:
  stage: validate
  tags:
    - macos
  script:
    - ./ValidationTools/Scripts/build_verification.sh
  artifacts:
    reports:
      junit: ValidationTools/Reports/build_verification_*.json
    paths:
      - ValidationTools/Reports/
    expire_in: 1 week

protocol_validation:
  stage: validate
  tags:
    - macos
  script:
    - ./ValidationTools/Scripts/protocol_validation.sh
  artifacts:
    paths:
      - ValidationTools/Reports/
    expire_in: 1 week

core_data_validation:
  stage: validate
  tags:
    - macos
  script:
    - ./ValidationTools/Scripts/core_data_validation.sh
  artifacts:
    paths:
      - ValidationTools/Reports/
    expire_in: 1 week

memory_validation:
  stage: validate
  tags:
    - macos
  script:
    - ./ValidationTools/Scripts/memory_profiling.sh
  artifacts:
    paths:
      - ValidationTools/Reports/
    expire_in: 1 week

generate_summary:
  stage: report
  tags:
    - macos
  dependencies:
    - build_validation
    - protocol_validation
    - core_data_validation
    - memory_validation
  script:
    - ./ValidationTools/Scripts/generate_validation_summary.sh
  artifacts:
    reports:
      junit: ValidationTools/Reports/validation_summary_*.json
    paths:
      - ValidationTools/Reports/
    expire_in: 1 month
```

## Azure DevOps Integration

Create `azure-pipelines.yml`:

```yaml
trigger:
  branches:
    include:
    - main
    - develop

pool:
  vmImage: 'macOS-latest'

variables:
  xcodeVersion: '15.1'

steps:
- task: Xcode@5
  displayName: 'Set Xcode Version'
  inputs:
    actions: 'selectversion'
    xcodeVersion: '$(xcodeVersion)'

- script: |
    brew install bc jq python3
  displayName: 'Install Dependencies'

- script: |
    ./ValidationTools/Scripts/run_validation.sh
  displayName: 'Run Validation'

- script: |
    ./ValidationTools/Scripts/generate_validation_summary.sh
  displayName: 'Generate Summary'

- task: PublishTestResults@2
  displayName: 'Publish Validation Results'
  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: 'ValidationTools/Reports/*.json'
    mergeTestResults: true

- task: PublishBuildArtifacts@1
  displayName: 'Publish Validation Reports'
  inputs:
    pathToPublish: 'ValidationTools/Reports'
    artifactName: 'validation-reports'
```

## Custom Integration Scripts

### Slack Notification Script

Create `ValidationTools/Scripts/notify_slack.sh`:

```bash
#!/bin/bash

WEBHOOK_URL="$1"
REPORT_FILE="$2"

if [ -z "$WEBHOOK_URL" ] || [ -z "$REPORT_FILE" ]; then
    echo "Usage: $0 <webhook_url> <report_file>"
    exit 1
fi

# Extract summary from report
STATUS=$(jq -r '.overall_status' "$REPORT_FILE")
SUCCESS_RATE=$(jq -r '.summary.success_rate' "$REPORT_FILE")

# Determine color
COLOR="good"
if [ "$STATUS" != "passed" ]; then
    COLOR="danger"
fi

# Send notification
curl -X POST -H 'Content-type: application/json' \
    --data "{
        \"attachments\": [{
            \"color\": \"$COLOR\",
            \"title\": \"DigitonePad Validation Results\",
            \"fields\": [
                {\"title\": \"Status\", \"value\": \"$STATUS\", \"short\": true},
                {\"title\": \"Success Rate\", \"value\": \"${SUCCESS_RATE}%\", \"short\": true}
            ]
        }]
    }" \
    "$WEBHOOK_URL"
```

### Email Report Script

Create `ValidationTools/Scripts/email_report.sh`:

```bash
#!/bin/bash

EMAIL="$1"
REPORT_FILE="$2"

if [ -z "$EMAIL" ] || [ -z "$REPORT_FILE" ]; then
    echo "Usage: $0 <email> <report_file>"
    exit 1
fi

# Generate email content
SUBJECT="DigitonePad Validation Report - $(date)"
BODY="Please find the attached validation report for DigitonePad."

# Send email with attachment
mail -s "$SUBJECT" -a "$REPORT_FILE" "$EMAIL" <<< "$BODY"
```

## Best Practices

### 1. Caching Strategy
- Cache Swift package dependencies
- Cache Xcode derived data when possible
- Use incremental builds for faster feedback

### 2. Parallel Execution
- Run validation categories in parallel
- Use matrix builds for different configurations
- Separate fast and slow tests

### 3. Failure Handling
- Continue validation even if one category fails
- Collect all reports before failing the build
- Provide detailed failure information

### 4. Reporting
- Archive all validation reports
- Generate human-readable summaries
- Send notifications to relevant teams

### 5. Security
- Store sensitive credentials in CI/CD secrets
- Use least-privilege access for CI/CD agents
- Regularly rotate access tokens

## Monitoring and Alerting

### Metrics to Track
- Validation success rate over time
- Memory usage trends
- Build time performance
- Test execution time

### Alert Conditions
- Validation failure rate > 10%
- Memory usage increase > 20%
- Build time increase > 50%
- Critical test failures

### Dashboard Integration
- Integrate with monitoring tools (Grafana, DataDog)
- Create validation trend charts
- Set up automated alerts

This CI/CD integration ensures continuous validation of the DigitonePad project across all development workflows.
