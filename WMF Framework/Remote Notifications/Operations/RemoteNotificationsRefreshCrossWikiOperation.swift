
import Foundation

class RemoteNotificationsRefreshCrossWikiGroupOperation: RemoteNotificationsOperation {
    
    enum CrossWikiGroupError: Error {
        case individualErrors([Error])
    }
    
    var crossWikiSummaryNotification: RemoteNotificationsAPIController.NotificationsResult.Notification?
    
    private let internalQueue = OperationQueue()
    private let finishingOperation = BlockOperation(block: {})
    
    private let appLanguageProject: RemoteNotificationsProject
    private let secondaryProjects: [RemoteNotificationsProject]
    private let languageLinkController: MWKLanguageLinkController
    private let fromRefresh: Bool
    
    init(appLanguageProject: RemoteNotificationsProject, secondaryProjects: [RemoteNotificationsProject], languageLinkController: MWKLanguageLinkController, apiController: RemoteNotificationsAPIController, modelController: RemoteNotificationsModelController, fromRefresh: Bool) {
        self.appLanguageProject = appLanguageProject
        self.secondaryProjects = secondaryProjects
        self.languageLinkController = languageLinkController
        self.fromRefresh = fromRefresh
        super.init(apiController: apiController, modelController: modelController)
    }
    
    required init(apiController: RemoteNotificationsAPIController, modelController: RemoteNotificationsModelController) {
        fatalError("init(apiController:modelController:) has not been implemented")
    }
    
    override func execute() {
        
        let crossWikiOperations = crossWikiOperations()
        for crossWikiOperation in crossWikiOperations {
            finishingOperation.addDependency(crossWikiOperation)
        }
        
        finishingOperation.completionBlock = {
            let errors = crossWikiOperations.compactMap { $0.error }
            if errors.count > 0 {
                self.finish(with: CrossWikiGroupError.individualErrors(errors))
            } else {
                self.finish()
            }
        }
        
        internalQueue.addOperations(crossWikiOperations + [finishingOperation], waitUntilFinished: false)
    }
    
    override func cancel() {
        internalQueue.cancelAllOperations()
        super.cancel()
    }
    
    private func crossWikiOperations() -> [RemoteNotificationsRefreshCrossWikiOperation] {
        
        guard let crossWikiSummary = crossWikiSummaryNotification,
              let crossWikiSources = crossWikiSummary.sources else {
            return []
        }
        
        let crossWikiProjects = crossWikiSources.keys.compactMap { RemoteNotificationsProject(apiIdentifier: $0, languageLinkController: languageLinkController) }
        
        //extract new projects from summary object that aren't already queued up to be fetched as an app language or secondary operation
        let filteredCrossWikiProjects = crossWikiProjects.filter { !([appLanguageProject] + secondaryProjects).contains($0) }

        return filteredCrossWikiProjects.map { RemoteNotificationsRefreshCrossWikiOperation(project: $0, apiController: self.apiController, modelController: self.modelController, needsCrossWikiSummary: false, fromRefresh: fromRefresh)}
    }
}

class RemoteNotificationsRefreshCrossWikiOperation: RemoteNotificationsPagingOperation {
    
    override var filter: RemoteNotificationsAPIController.Query.Filter {
        return .unread
    }
    
}
