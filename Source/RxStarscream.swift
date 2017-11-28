//
//  Created by Guy Kahlon.
//

import Foundation
import RxSwift
import RxCocoa
import Starscream

public enum WebSocketEvent {
  case connected
  case disconnected(Error?)
  case message(String)
  case data(Foundation.Data)
  case pong
}

public class RxWebSocketDelegateProxy: DelegateProxy<WebSocket, AnyObject>,
                                       WebSocketDelegate,
                                       WebSocketPongDelegate,
                                       DelegateProxyType {
    
    
    public static func registerKnownImplementations() {
    }
    
    public typealias ParentObject = WebSocket
    public typealias Delegate = AnyObject

    public static func setCurrentDelegate(_ delegate: AnyObject?, to object: WebSocket) {
        let webSocket = object
        webSocket.delegate = delegate as? WebSocketDelegate
        webSocket.pongDelegate = delegate as? WebSocketPongDelegate
    }

    public static func currentDelegate(for object: WebSocket) -> AnyObject? {
        return object.delegate
    }

    private weak var forwardDelegate: WebSocketDelegate?
    private weak var forwardPongDelegate: WebSocketPongDelegate?

    fileprivate let subject = PublishSubject<WebSocketEvent>()
    
    public override init<Proxy>(parentObject: ParentObject, delegateProxy: Proxy.Type) where ParentObject == Proxy.ParentObject, Delegate == Proxy.Delegate, Proxy : DelegateProxy<ParentObject, Delegate>, Proxy : DelegateProxyType {
        let webSocket = parentObject
        self.forwardDelegate = webSocket.delegate
        self.forwardPongDelegate = webSocket.pongDelegate
        super.init(parentObject: parentObject, delegateProxy: delegateProxy)
    }
    
    public func websocketDidConnect(socket: WebSocketClient) {
        subject.on(.next(WebSocketEvent.connected))
        forwardDelegate?.websocketDidConnect(socket: socket)
    }

    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        subject.on(.next(WebSocketEvent.disconnected(error)))
        forwardDelegate?.websocketDidDisconnect(socket: socket, error: error)
    }

    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        subject.on(.next(WebSocketEvent.message(text)))
        forwardDelegate?.websocketDidReceiveMessage(socket: socket, text: text)
    }

    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        subject.on(.next(WebSocketEvent.data(data)))
        forwardDelegate?.websocketDidReceiveData(socket: socket, data: data)
    }

    public func websocketDidReceivePong(socket: WebSocketClient, data: Data?) {
        subject.on(.next(WebSocketEvent.pong))
        forwardPongDelegate?.websocketDidReceivePong(socket: socket, data: data)
    }

    deinit {
        subject.on(.completed)
    }
}

extension Reactive where Base: WebSocket {

    public var response: Observable<WebSocketEvent> {
        return RxWebSocketDelegateProxy.proxy(for: base).subject
    }

    public var text: Observable<String> {
        return self.response.filter { response in
            switch response {
            case .message(_):
                return true
            default:
                return false
            }
        }.map { response in
            switch response {
            case .message(let message):
                return message
            default:
                return String()
            }
        }
    }

    public var connected: Observable<Bool> {
        return response.filter { response in
            switch response {
            case .connected, .disconnected(_):
                return true
            default:
                return false
            }
        }.map { response in
            switch response {
            case .connected:
                return true
            default:
                return false
            }
        }
    }

    public func write(data: Data) -> Observable<Void> {
        return Observable.create { sub in
            self.base.write(data: data) {
                sub.onNext(())
                sub.onCompleted()
            }
            return Disposables.create()
        }
    }

    func write(ping: Data) -> Observable<Void> {
        return Observable.create { sub in
            self.base.write(ping: ping) {
                sub.onNext(())
                sub.onCompleted()
            }
            return Disposables.create()
        }
    }

    func write(string: String) -> Observable<Void> {
        return Observable.create { sub in
            self.base.write(string: string) {
                sub.onNext(())
                sub.onCompleted()
            }
            return Disposables.create()
        }
    }
}
