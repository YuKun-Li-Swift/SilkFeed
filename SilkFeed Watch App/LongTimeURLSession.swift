//
//  LongTimeURLSession.swift
//  SilkFeed
//
//  Created by Yukun Li on 2024/11/5.
//

import Foundation


struct URLSessionToolKit {
    static
    func getURLSessionConfig(waitsForConnectivity:Bool,timeout:TimeInterval) -> (URLSessionConfiguration) {
        let urlSessionConfig = URLSessionConfiguration.default
        urlSessionConfig.waitsForConnectivity = waitsForConnectivity
        urlSessionConfig.shouldUseExtendedBackgroundIdleMode = true
        urlSessionConfig.timeoutIntervalForRequest = timeout
        urlSessionConfig.timeoutIntervalForResource = timeout
        return (urlSessionConfig)
    }
    
    static
    func getURLRequest(url:URL) -> (URLRequest) {
        let urlRequest = URLRequest(url: url,cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,timeoutInterval: 60*60/*1h*/)
        return (urlRequest)
    }
}
