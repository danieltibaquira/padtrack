# Xcode Cloud Setup Guide for DigitonePad

## Overview
This guide walks you through setting up Xcode Cloud for automatic TestFlight builds when PRs are merged to the main branch.

## ✅ Prerequisites Completed
- Apple Developer Team ID: `GN9UGD54YC`
- Bundle ID: `com.digitonepad.app`
- Code Signing: Automatic
- Admin access confirmed

## 🚀 Setup Instructions

### Step 1: Configure App Store Connect

1. **Create App in App Store Connect**
   - Go to [App Store Connect](https://appstoreconnect.apple.com)
   - Click **My Apps** → **+** → **New App**
   - Fill in the details:
     - **Platform**: iOS
     - **Name**: DigitonePad
     - **Primary Language**: English (U.S.)
     - **Bundle ID**: `com.digitonepad.app`
     - **SKU**: `digitonepad-ios` (or your preference)
   - Click **Create**

2. **Configure App Information**
   - Set **Category**: Music
   - Set **Content Rights**: Does Not Use Third-Party Content
   - Configure privacy settings as needed

### Step 2: Enable Xcode Cloud

1. **Access Xcode Cloud**
   - In App Store Connect, go to your DigitonePad app
   - Click on **Xcode Cloud** tab
   - Click **Get Started**

2. **Connect Repository**
   - Select **GitHub** as source control provider
   - Authorize App Store Connect to access your GitHub account
   - Select the `padtrack` repository
   - Grant necessary permissions

### Step 3: Create Workflow

1. **Create New Workflow**
   - Click **Create Workflow**
   - Name: `TestFlight Production Build`
   - Description: `Automatic TestFlight build on main branch merge`

2. **Configure Start Conditions**
   - **Source**: Select your repository
   - **Branch**: `main`
   - **Changes**: `Any change to source code`

3. **Configure Environment**
   - **Xcode Version**: Latest Release (15.2+)
   - **macOS Version**: Latest Release (14.2+)
   - **Clean**: Enabled

4. **Configure Actions**
   - **Archive**: Enabled
   - **Scheme**: `DigitonePad`
   - **Platform**: iOS
   - **Configuration**: Release

5. **Configure Post-Actions**
   - **TestFlight Internal Testing**: Enabled
   - **Automatically manage version**: Enabled
   - **Export Compliance**: Set appropriately for your app

### Step 4: Configure Code Signing

1. **Automatic Code Signing** (Recommended)
   - Xcode Cloud will automatically manage certificates and profiles
   - Ensure your Apple Developer account has the necessary permissions

2. **Manual Code Signing** (If needed)
   - Upload Distribution Certificate
   - Upload App Store Provisioning Profile
   - Configure in workflow settings

### Step 5: Test the Workflow

1. **Manual Test**
   - Go to Xcode Cloud → Workflows
   - Select your workflow
   - Click **Start Build**
   - Monitor the build process

2. **Automatic Test**
   - Create a test PR and merge to main
   - Verify the workflow triggers automatically
   - Check build status and TestFlight distribution

## 📁 Files Already Created

The following files have been created in your repository:

### CI Scripts (`ci_scripts/`)
- `ci_post_clone.sh` - Installs dependencies after cloning
- `ci_pre_xcodebuild.sh` - Generates Xcode project before building
- `ci_post_xcodebuild.sh` - Validates build after completion

### Test Plan
- `DigitonePad.xctestplan` - Comprehensive test plan for CI/CD

## 🔧 Workflow Configuration

Your Xcode Cloud workflow will:

1. **Trigger** on every push to `main` branch
2. **Clone** repository and run `ci_post_clone.sh`
3. **Generate** Xcode project using `xcodegen`
4. **Build** DigitonePad scheme in Release configuration
5. **Archive** the app for distribution
6. **Upload** to TestFlight automatically
7. **Notify** about build status

## 📱 TestFlight Configuration

### Internal Testing
- Builds will be available to internal testers immediately
- No review required for internal testing
- Up to 100 internal testers supported

### External Testing
- Set up external testing groups as needed
- Beta App Review required for external testing
- Up to 10,000 external testers supported

## 🔍 Monitoring and Debugging

### Build Status
- Monitor builds in App Store Connect → Xcode Cloud
- View detailed logs for each build step
- Check GitHub for status checks

### Common Issues and Solutions

1. **Project Generation Fails**
   - Check `project.yml` syntax
   - Verify all dependencies are available

2. **Code Signing Issues**
   - Ensure automatic code signing is enabled
   - Verify team membership and permissions

3. **Build Failures**
   - Check CI script logs
   - Verify scheme configuration
   - Test locally with `xcodegen generate`

## 📋 Next Steps

After setup completion:

1. **Test the complete pipeline**:
   - Create a test branch
   - Make a small change
   - Create PR and merge to main
   - Verify TestFlight build appears

2. **Configure TestFlight groups**:
   - Set up internal testing team
   - Create external testing groups if needed
   - Configure beta app information

3. **Set up notifications**:
   - Configure Slack/email notifications
   - Set up build status monitoring
   - Create dashboard for build tracking

## 🚨 Important Notes

- **First build may take 15-20 minutes** to set up environment
- **Subsequent builds typically take 5-10 minutes**
- **Builds are queued** - may wait if many builds in progress
- **Monthly build minutes** are limited based on your plan

## 📞 Support

If you encounter issues:

1. Check Xcode Cloud documentation
2. Review build logs in App Store Connect
3. Verify GitHub integration status
4. Test local build with same configuration

---

## ✅ Quick Checklist

- [ ] App created in App Store Connect
- [ ] Xcode Cloud enabled
- [ ] Repository connected
- [ ] Workflow created and configured
- [ ] Code signing configured
- [ ] Test build completed successfully
- [ ] TestFlight distribution working
- [ ] Team notifications set up

Once all items are checked, your Xcode Cloud pipeline will automatically create TestFlight builds whenever code is merged to the main branch!