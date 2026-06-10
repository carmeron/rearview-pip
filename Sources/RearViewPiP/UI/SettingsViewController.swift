import UIKit
import Combine

/// Settings view controller for adjusting app configuration.
final class SettingsViewController: UIViewController {
    private let configManager = ConfigurationManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI Elements

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private enum Section: Int, CaseIterable {
        case guideLine
        case detection
        case display
        case about

        var title: String {
            switch self {
            case .guideLine: return "辅助线样式"
            case .detection: return "信号检测"
            case .display: return "显示设置"
            case .about: return "关于"
            }
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservers()
    }

    // MARK: - UI Setup

    private func setupUI() {
        title = "设置"
        view.backgroundColor = .systemGroupedBackground

        // Close button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissSettings)
        )

        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Reset button
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 80))
        let resetButton = UIButton(type: .system)
        resetButton.setTitle("重置所有设置", for: .normal)
        resetButton.setTitleColor(.systemRed, for: .normal)
        resetButton.addTarget(self, action: #selector(resetSettings), for: .touchUpInside)
        resetButton.frame = footerView.bounds
        footerView.addSubview(resetButton)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            resetButton.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
            resetButton.centerYAnchor.constraint(equalTo: footerView.centerYAnchor)
        ])
        tableView.tableFooterView = footerView
    }

    private func setupObservers() {
        configManager.configurationDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func dismissSettings() {
        dismiss(animated: true)
    }

    @objc private func resetSettings() {
        let alert = UIAlertController(
            title: "重置设置",
            message: "确定要恢复所有设置为默认值吗？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "重置", style: .destructive) { [weak self] _ in
            self?.configManager.resetToDefaults()
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .guideLine: return GuideLineStyle.allCases.count
        case .detection: return Sensitivity.allCases.count + 1  // +1 for description
        case .display: return 1
        case .about: return 3
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        let config = configManager.loadConfiguration()

        switch section {
        case .guideLine:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            let style = GuideLineStyle.allCases[indexPath.row]
            cell.textLabel?.text = style.displayName
            cell.accessoryType = (config.guideLineStyle == style) ? .checkmark : .none
            return cell

        case .detection:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

            if indexPath.row < Sensitivity.allCases.count {
                let sensitivity = Sensitivity.allCases[indexPath.row]
                cell.textLabel?.text = "灵敏度: \(sensitivity.displayName)"
                cell.accessoryType = (config.detectionSensitivity == sensitivity) ? .checkmark : .none
                cell.selectionStyle = .default
            } else {
                cell.textLabel?.text = "较低灵敏度需要更明显的信号变化才能触发切换"
                cell.textLabel?.font = .systemFont(ofSize: 13)
                cell.textLabel?.textColor = .secondaryLabel
                cell.textLabel?.numberOfLines = 0
                cell.selectionStyle = .none
                cell.accessoryType = .none
            }
            return cell

        case .display:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.textLabel?.text = "视觉警报(红色边框闪烁)"

            let toggle = UISwitch()
            toggle.isOn = config.visualAlertsEnabled
            toggle.addTarget(self, action: #selector(visualAlertsToggled(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
            return cell

        case .about:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.selectionStyle = .none
            cell.accessoryType = .none

            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "版本: 1.0.0"
            case 1:
                cell.textLabel?.text = "系统要求: iPadOS 15.0+"
            case 2:
                cell.textLabel?.text = "技术栈: Swift 5.x • AVFoundation • AVKit"
            default:
                break
            }
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = Section(rawValue: indexPath.section) else { return }

        switch section {
        case .guideLine:
            let style = GuideLineStyle.allCases[indexPath.row]
            configManager.setGuideLineStyle(style)
            tableView.reloadSections(IndexSet(integer: Section.guideLine.rawValue), with: .none)

        case .detection:
            guard indexPath.row < Sensitivity.allCases.count else { return }
            let sensitivity = Sensitivity.allCases[indexPath.row]
            configManager.setSensitivity(sensitivity)
            tableView.reloadSections(IndexSet(integer: Section.detection.rawValue), with: .none)

        default:
            break
        }
    }

    @objc private func visualAlertsToggled(_ sender: UISwitch) {
        configManager.setVisualAlertsEnabled(sender.isOn)
    }
}
