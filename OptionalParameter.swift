//
//  OptionalParameter.swift
//  Pods
//
//  Created by wzy on 2017/7/6.
//
//

import UIKit

public struct OptionalParameter {
    public var vendor:String?
    public var broker:String?
    public var accessKey:String?
    public var secretKey:String?
    public var topic:String?
    public var producerClientId:String?
}

extension OptionalParameter{
    
    public init(v:String,b:String,a:String,s:String,t:String,p:String) {
        vendor = v;
        broker = b;
        accessKey = a;
        secretKey = s;
        topic = t;
        producerClientId = p;
    }
    
}
