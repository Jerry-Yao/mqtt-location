//
//  LocationSingle.swift
//  ddicar-mqtt-location
//
//  Created by wzy on 2017/7/4.
//  Copyright © 2017年 CocoaPods. All rights reserved.
//

import UIKit
import CoreLocation
import CocoaMQTT
import CryptoSwift
//import SwiftQueue

protocol SinglePushManagerLocationDelegate : class {
    func LocationManager(loctionJsonString: String)
}

public class SinglePushManager: NSObject,CLLocationManagerDelegate{
    
    public let locationManager = CLLocationManager()
    var mqtt: CocoaMQTT?
    var queuedTasks = Array<Any>()
    public var vendor:String?
    public var broker:String?
    public var accessKey:String?
    public var secretKey:String?
    public var topic:String?
    public var producerClientId:String?
    public var host:String?
    private var uid:String?
    
    var delegate:SinglePushManagerLocationDelegate?
    
    public class func setupMqtt(imei: String, username: String ,password: String,host: String){
        SinglePushManager.sharedManager.setParameter(imeiStr: imei, access:username ,secret:password ,hostStr:host)
        SinglePushManager.sharedManager.mqttSetting()
    }
    
    public static let sharedManager: SinglePushManager = {
        SinglePushManager()
    } ()
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest //定位精确度（最高）一般有电源接入，比较耗电
        locationManager.requestAlwaysAuthorization()//弹出用户授权对话框，使用程序期间授权（ios8后)
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.distanceFilter = kCLDistanceFilterNone //定位更新的最小距离为空
        if #available(iOS 9.0, *) {
            locationManager.allowsBackgroundLocationUpdates = true
        } else {
            // Fallback on earlier versions
        }
    }
    //    public var accessKey:String?
    //    public var secretKey:String?
    
    public func setParameter(imeiStr:String, access:String ,secret:String ,hostStr:String) {
        self.producerClientId = imeiStr
        self.accessKey = access
        self.secretKey = secret
        self.host = hostStr
        self.uid = imeiStr
    }
    public class func startUpdate(){
        SinglePushManager.sharedManager.locationManager.startUpdatingLocation()
        
    }
    
    //MARK CLLocationManagerDelegate
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if uid == nil { return }
        let currLocation:CLLocation = locations.last!
        
        let speed : String = "\(currLocation.speed > 0 ? currLocation.speed : 0)"
        let longitude : String = "\(fabs(currLocation.coordinate.longitude))"//经度
        let latitude : String = "\(fabs(currLocation.coordinate.latitude))"//纬度
//        let identifier : String = UIDevice.current.identifierForVendor!.uuidString
        let identifier : String = uid ?? ""
        let altitude : String = "\(currLocation.altitude)"//海拔

        let date = Date();
        let formatter = DateFormatter();
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'";
        formatter.timeZone = TimeZone(abbreviation: "UTC");
        let utcTimeZoneStr = formatter.string(from: date);
        
        let dic = ["v":speed,"lon":longitude,"alt":altitude,"lat":latitude,"date":utcTimeZoneStr,"imei":identifier.lowercased(), "vendor": "app"]
        self.sendMessage(dict: dic)
    }
    
    
    func mqttSetting() {
        do {
            let bytes = "GID_tracks".data(using: .utf8)?.bytes
            
            if let client = producerClientId, let h = host{
                let clientID = "GID_tracks@@@" + client
                mqtt = CocoaMQTT(clientID: clientID, host: h, port: 1883)
            }
            
            if let m = mqtt {
                m.delegate = self
                if let pw = secretKey {
                    let hmac: [UInt8] = try HMAC(key: Array(pw.utf8), variant: .sha1).authenticate(bytes!)
                    m.password = hmac.toBase64()!
                }
                
                if let username = accessKey {
                    m.username = username
                }
                
//                m.willMessage = CocoaMQTTWill(topic: "tracks", message: "dieout")
                m.keepAlive = 60
                m.connect()
            }
        } catch {}
        
    }
    
    func sendMessage(dict: [String: Any?]) {

        let data = try? JSONSerialization.data(withJSONObject: dict, options: [])
        let message = String(data: data!, encoding: .utf8)
        
        if let m = message {
            if !m.isEmpty{
                delegate?.LocationManager(loctionJsonString: m)
            }
            
            if (mqtt?.connState == .connected && !m.isEmpty) {
                mqtt?.publish("tracks", withString: m, qos: .qos0)
                
            }
        }
    }
}
/////
extension SinglePushManager: CocoaMQTTDelegate {
    public func mqtt(_ mqtt: CocoaMQTT, didConnect host: String, port: Int) {
        print("didConnect \(host):\(port)")
    }
    
    // Optional ssl CocoaMQTTDelegate
    public func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        /// Validate the server certificate
        ///
        /// Some custom validation...
        ///
        /// if validatePassed {
        ///     completionHandler(true)
        /// } else {
        ///     completionHandler(false)
        /// }
        completionHandler(true)
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        print("didConnectAck: \(ack)，rawValue: \(ack.rawValue)")
        
        if ack == .accept {
            //            mqtt.subscribe("tracks", qos: CocoaMQTTQOS.qos0)
            
        }
        
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
//        print("didPublishMessage with message: \(String(describing: message.string))")
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        print("didPublishAck with id: \(id)")
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 ) {
        print("didReceivedMessage: \(String(describing: message.string)) with id \(id)")
        //        let name = NSNotification.Name(rawValue: "MQTTMessageNotification" + animal!)
        //        NotificationCenter.default.post(name: name, object: self, userInfo: ["message": message.string!, "topic": message.topic])
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topic: String) {
        print("didSubscribeTopic to \(topic)")
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopic topic: String) {
        print("didUnsubscribeTopic to \(topic)")
    }
    
    public func mqttDidPing(_ mqtt: CocoaMQTT) {
        print("didPing")
    }
    
    public func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        _console("didReceivePong")
    }
    
    public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        _console("mqttDidDisconnect")
        print(err as Any)
    }
    
    func _console(_ info: String) {
        print("Delegate: \(info)")
    }
}


