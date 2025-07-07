// MIDIViewController.swift
// DigitonePad - MIDIModule
//
// VIPER View for MIDI user interface

#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

#if canImport(UIKit)
/// View Controller that handles MIDI user interface
public final class MIDIViewController: UIViewController, MIDIViewProtocol {
    public var presenter: MIDIPresenterProtocol?
    
    // MARK: - UI Components
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "MIDI Module"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Status: Disconnected"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.textColor = .systemRed
        return label
    }()
    
    private lazy var devicesTableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MIDIDeviceTableViewCell.self, forCellReuseIdentifier: "MIDIDeviceCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    private lazy var refreshButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Refresh Devices", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.addTarget(self, action: #selector(refreshButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var activityLabel: UILabel = {
        let label = UILabel()
        label.text = "No MIDI activity"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.textColor = .systemGray
        label.numberOfLines = 0
        return label
    }()
    
    // MARK: - Private Properties
    private var midiDevices: [MIDIDevice] = []
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter?.viewDidLoad()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "MIDI"
        
        view.addSubview(stackView)
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(statusLabel)
        stackView.addArrangedSubview(refreshButton)
        stackView.addArrangedSubview(devicesTableView)
        stackView.addArrangedSubview(activityLabel)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            
            devicesTableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func refreshButtonTapped() {
        presenter?.refreshMIDIDevices()
    }
    
    // MARK: - MIDIViewProtocol
    
    public func showMIDIDevices(_ devices: [MIDIDevice]) {
        DispatchQueue.main.async { [weak self] in
            self?.midiDevices = devices
            self?.devicesTableView.reloadData()
        }
    }
    
    public func showMIDIConnection(status: MIDIConnectionStatus) {
        DispatchQueue.main.async { [weak self] in
            switch status {
            case .disconnected:
                self?.statusLabel.text = "Status: Disconnected"
                self?.statusLabel.textColor = .systemRed
            case .connecting:
                self?.statusLabel.text = "Status: Connecting..."
                self?.statusLabel.textColor = .systemOrange
            case .connected:
                self?.statusLabel.text = "Status: Connected"
                self?.statusLabel.textColor = .systemGreen
            case .error:
                self?.statusLabel.text = "Status: Error"
                self?.statusLabel.textColor = .systemRed
            }
        }
    }
    
    public func showMIDIActivity(message: MIDIMessage) {
        DispatchQueue.main.async { [weak self] in
            let activityText = "MIDI: \(message.type) Ch:\(message.channel + 1) Data:\(message.data1),\(message.data2)"
            self?.activityLabel.text = activityText
            self?.activityLabel.textColor = .systemBlue
            
            // Reset to gray after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self?.activityLabel.textColor = .systemGray
            }
        }
    }
    
    public func showError(_ error: MIDIError) {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "MIDI Error",
                message: error.message,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
}

// MARK: - UITableViewDataSource

extension MIDIViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return midiDevices.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MIDIDeviceCell", for: indexPath) as! MIDIDeviceTableViewCell
        let device = midiDevices[indexPath.row]
        cell.configure(with: device)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension MIDIViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let device = midiDevices[indexPath.row]
        
        if device.isConnected {
            presenter?.disconnectFromDevice(device)
        } else {
            presenter?.connectToDevice(device)
        }
    }
}

// MARK: - Custom Table View Cell

private final class MIDIDeviceTableViewCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with device: MIDIDevice) {
        textLabel?.text = device.name
        detailTextLabel?.text = "\(device.manufacturer) - \(device.connectionDirection.rawValue.capitalized)"
        
        if device.isConnected {
            accessoryType = .checkmark
            textLabel?.textColor = .systemBlue
        } else {
            accessoryType = .none
            textLabel?.textColor = device.isOnline ? .label : .systemGray
        }
    }
}
#endif 