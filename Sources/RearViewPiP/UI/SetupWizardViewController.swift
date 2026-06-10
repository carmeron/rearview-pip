import UIKit

/// First-time setup wizard that guides users through the initial configuration.
final class SetupWizardViewController: UIViewController {
    /// Callback invoked when setup is completed
    var onSetupCompleted: (() -> Void)?

    // MARK: - UI Elements

    private let pageControl = UIPageControl()
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let nextButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)

    private var currentPage: Int = 0 {
        didSet {
            pageControl.currentPage = currentPage
            updateButtons()
            scrollToPage(currentPage)
        }
    }

    private let totalPages = 3

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "初始设置"

        // Scroll view for paged content
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isScrollEnabled = false  // Only navigate via buttons
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Content stack — horizontal pages
        contentStack.axis = .horizontal
        contentStack.distribution = .fillEqually
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // Page 1: Welcome
        let welcomePage = createWelcomePage()
        contentStack.addArrangedSubview(welcomePage)

        // Page 2: Hardware setup guide
        let hardwarePage = createHardwarePage()
        contentStack.addArrangedSubview(hardwarePage)

        // Page 3: Shortcut automation guide
        let shortcutPage = createShortcutPage()
        contentStack.addArrangedSubview(shortcutPage)

        // Page control
        pageControl.numberOfPages = totalPages
        pageControl.currentPage = 0
        pageControl.currentPageIndicatorTintColor = .systemBlue
        pageControl.pageIndicatorTintColor = .systemGray4
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageControl)

        // Next button
        nextButton.setTitle("下一步", for: .normal)
        nextButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        nextButton.backgroundColor = .systemBlue
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.layer.cornerRadius = 12
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        view.addSubview(nextButton)

        // Skip button
        skipButton.setTitle("跳过", for: .normal)
        skipButton.titleLabel?.font = .systemFont(ofSize: 15)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        view.addSubview(skipButton)

        // Layout
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -20),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, multiplier: CGFloat(totalPages)),

            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -20),

            nextButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            nextButton.bottomAnchor.constraint(equalTo: skipButton.topAnchor, constant: -12),
            nextButton.heightAnchor.constraint(equalToConstant: 50),

            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Page Creation

    private func createWelcomePage() -> UIView {
        let container = UIView()

        let iconLabel = UILabel()
        iconLabel.text = "🚗"
        iconLabel.font = .systemFont(ofSize: 64)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconLabel)

        let titleLabel = UILabel()
        titleLabel.text = "欢迎使用 RearViewPiP"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let descLabel = UILabel()
        descLabel.text = "为您的别克GL8 28T提供智能倒车影像显示方案\n\n通过画中画窗口实现常驻显示\n智能检测倒车状态，自动切换内容"
        descLabel.font = .systemFont(ofSize: 16)
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        descLabel.textColor = .secondaryLabel
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descLabel)

        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -80),

            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40)
        ])

        return container
    }

    private func createHardwarePage() -> UIView {
        let container = UIView()

        let iconLabel = UILabel()
        iconLabel.text = "🔌"
        iconLabel.font = .systemFont(ofSize: 64)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconLabel)

        let titleLabel = UILabel()
        titleLabel.text = "硬件连接"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let descLabel = UILabel()
        descLabel.text = """
        请按以下顺序连接硬件：

        1. 将AV线缆从倒车摄像头连接到UVC采集卡
        2. 将UVC采集卡USB连接到Lightning转接器
        3. 将Lightning转接器插入iPad
        4. ⚠️ 务必连接5V/2A外部电源到转接器

        所需硬件：
        • Apple Lightning to USB 3 Camera Adapter
        • AV转USB (UVC) 视频采集卡
        • 车载5V/2A USB电源适配器
        """
        descLabel.font = .systemFont(ofSize: 15)
        descLabel.textAlignment = .left
        descLabel.numberOfLines = 0
        descLabel.textColor = .secondaryLabel
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descLabel)

        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 60),

            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40)
        ])

        return container
    }

    private func createShortcutPage() -> UIView {
        let container = UIView()

        let iconLabel = UILabel()
        iconLabel.text = "⚙️"
        iconLabel.font = .systemFont(ofSize: 64)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconLabel)

        let titleLabel = UILabel()
        titleLabel.text = "开机自启动设置"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let descLabel = UILabel()
        descLabel.text = """
        请手动配置快捷指令自动化：

        1. 打开iPad「快捷指令」App
        2. 点击底部「自动化」标签
        3. 点击右上角「+」
        4. 选择「创建个人自动化」
        5. 选择「解锁时」触发条件
        6. 添加操作 → 搜索「打开App」
        7. 选择「RearViewPiP」
        8. 关闭「运行前询问」开关
        9. 点击「完成」

        提示：配置后每次解锁iPad都会自动启动本应用并进入画中画模式
        """
        descLabel.font = .systemFont(ofSize: 15)
        descLabel.textAlignment = .left
        descLabel.numberOfLines = 0
        descLabel.textColor = .secondaryLabel
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(descLabel)

        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 60),

            titleLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40)
        ])

        return container
    }

    // MARK: - Navigation

    private func scrollToPage(_ page: Int) {
        let offsetX = scrollView.bounds.width * CGFloat(page)
        scrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: true)
    }

    private func updateButtons() {
        if currentPage == totalPages - 1 {
            nextButton.setTitle("完成设置", for: .normal)
        } else {
            nextButton.setTitle("下一步", for: .normal)
        }

        skipButton.isHidden = (currentPage == totalPages - 1)
    }

    @objc private func nextButtonTapped() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        } else {
            completeSetup()
        }
    }

    @objc private func skipButtonTapped() {
        completeSetup()
    }

    private func completeSetup() {
        ConfigurationManager.shared.markSetupCompleted()
        dismiss(animated: true) { [weak self] in
            self?.onSetupCompleted?()
        }
    }
}
