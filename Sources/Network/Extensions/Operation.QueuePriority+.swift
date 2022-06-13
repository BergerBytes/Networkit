//
//  File.swift
//  
//
//  Created by Michael Berger on 5/28/22.
//

import Foundation

extension Operation.QueuePriority: CustomStringConvertible {
    public var description: String {
        switch self {
        case .veryLow:
            return "veryLow"
            
        case .low:
            return "low"
            
        case .normal:
            return "normal"
            
        case .high:
            return "high"
            
        case .veryHigh:
            return "veryHigh"
            
        @unknown default:
            return "unknown"
        }
    }
    
    func increment() -> Self {
        switch self {
        case .veryLow:
            return .normal
            
        case .low:
            return .normal
            
        case .normal:
            return .high
            
        case .high:
            return .veryHigh
            
        case .veryHigh:
            return .veryHigh
            
        @unknown default:
            return self
        }
    }
    
    func decrement() -> Self {
        switch self {
        case .veryLow:
            return .veryLow
            
        case .low:
            return .veryLow
            
        case .normal:
            return .low
            
        case .high:
            return .normal
            
        case .veryHigh:
            return .high
            
        @unknown default:
            return self
        }
    }
}
