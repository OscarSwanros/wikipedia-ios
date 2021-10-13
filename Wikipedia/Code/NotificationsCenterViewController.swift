import UIKit

@objc
final class NotificationsCenterViewController: ViewController {

    // MARK: - Properties

    var notificationsView: NotificationsCenterView {
        return view as! NotificationsCenterView
    }

    let viewModel: NotificationsCenterViewModel
    
    typealias DataSource = UICollectionViewDiffableDataSource<NotificationsCenterSection, NotificationsCenterCellViewModel>
    typealias Snapshot = NSDiffableDataSourceSnapshot<NotificationsCenterSection, NotificationsCenterCellViewModel>
    private lazy var dataSource = makeDataSource()
    
    private let editTitle = WMFLocalizedString("notifications-center-edit-button-edit", value: "Edit", comment: "Title for navigation bar button to turn on edit mode for toggling notification read status")
    private let doneTitle = WMFLocalizedString("notifications-center-edit-button-done", value: "Done", comment: "Title for navigation bar button to turn off edit mode for toggling notification read status")
    private lazy var editButton = {
        return UIBarButtonItem(title: editTitle, style: .plain, target: self, action: #selector(userDidTapEditButton))
    }()

    // MARK: - Lifecycle

    @objc
    init(theme: Theme, viewModel: NotificationsCenterViewModel) {
        self.viewModel = viewModel
        super.init(theme: theme)
        viewModel.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

	override func loadView() {
		view = NotificationsCenterView(frame: UIScreen.main.bounds)
		scrollView = notificationsView.collectionView
	}

    override func viewDidLoad() {
        super.viewDidLoad()

        notificationsView.apply(theme: theme)

		title = CommonStrings.notificationsCenterTitle
		setupBarButtons()
        
        setupCollectionView()
        viewModel.fetchFirstPage()
	}
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //viewModel.refreshNotifications()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            notificationsView.collectionView.reloadData()
        }
    }

	// MARK: - Configuration

    fileprivate func setupBarButtons() {
        enableToolbar()
        setToolbarHidden(false, animated: false)

		navigationItem.rightBarButtonItem = editButton
	}

	// MARK: - Edit button

	@objc func userDidTapEditButton() {
        viewModel.editMode.toggle()
        editButton.title = viewModel.editMode ? doneTitle : editTitle
	}

	// MARK: - Public


    // MARK: - Themable

    override func apply(theme: Theme) {
        super.apply(theme: theme)

        notificationsView.apply(theme: theme)
        notificationsView.collectionView.reloadData()
    }
}

//MARK: Private

private extension NotificationsCenterViewController {
    func setupCollectionView() {
        notificationsView.collectionView.delegate = self
    }
    
    func makeDataSource() -> DataSource {
        let dataSource = DataSource(
            collectionView: notificationsView.collectionView,
            cellProvider: { [weak self] (collectionView, indexPath, viewModel) ->
                UICollectionViewCell? in

                guard let self = self,
                      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NotificationsCenterCell.reuseIdentifier, for: indexPath) as? NotificationsCenterCell else {
                    return nil
                }
                cell.configure(viewModel: viewModel, theme: self.theme, indexPath: indexPath)
                cell.delegate = self
                return cell
            })
        return dataSource
    }
    
    func applySnapshot(cellViewModels: [NotificationsCenterCellViewModel], animatingDifferences: Bool = true) {
        DispatchQueue.main.async {
            var snapshot = Snapshot()
            snapshot.appendSections([.main])
            snapshot.appendItems(cellViewModels)
            print("🌀\(Thread.isMainThread)")
            self.dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
        }
    }
}

// MARK: - NotificationCenterViewModelDelegate

extension NotificationsCenterViewController: NotificationCenterViewModelDelegate {
    func cellViewModelsDidChange(cellViewModels: [NotificationsCenterCellViewModel]) {
        applySnapshot(cellViewModels: cellViewModels, animatingDifferences: true)
    }
    
    func reloadCellWithViewModelIfNeeded(_ viewModel: NotificationsCenterCellViewModel) {
        for cell in notificationsView.collectionView.visibleCells {
            guard let cell = cell as? NotificationsCenterCell,
                  let cellViewModel = cell.viewModel,
                  cellViewModel == viewModel else {
                continue
            }
            
            cell.configure(viewModel: viewModel, theme: theme, indexPath: nil)
        }
    }
}

extension NotificationsCenterViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let count = dataSource.collectionView(collectionView, numberOfItemsInSection: indexPath.section)
        let isLast = indexPath.row == count - 1
        if isLast {
            viewModel.fetchNextPage()
        }
    }
}

extension NotificationsCenterViewController: NotificationsCenterCellDelegate {
    func userDidTapSecondaryActionForCellIdentifier(id: String) {
        //TODO
    }
    
    func toggleCheckedStatus(viewModel: NotificationsCenterCellViewModel) {
        self.viewModel.toggleCheckedStatus(cellViewModel: viewModel)
    }
}
