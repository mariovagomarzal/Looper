public let stableLooperAppId: String = "com.mariovagomarzal.looper"
#if DEBUG
    public let looperAppId: String = "com.mariovagomarzal.looper.debug"
    public let looperAppName: String = "Looper-Debug"
#else
    public let looperAppId: String = stableLooperAppId
    public let looperAppName: String = "Looper"
#endif
