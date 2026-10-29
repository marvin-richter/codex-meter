/// Errors presented by the usage store and popover.
enum AppError: Error {
    case appServer(AppServerProvider.ProviderError)
    case unexpected
}
