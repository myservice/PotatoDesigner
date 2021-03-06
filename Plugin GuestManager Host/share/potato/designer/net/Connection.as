package potato.designer.net
{
	import flash.utils.ByteArray;
	
	CONFIG::HOST
	{
		import flash.events.Event;
		import flash.events.EventDispatcher;
		import flash.events.IOErrorEvent;
		import flash.events.ProgressEvent;
		import flash.net.Socket;
	}
		
	CONFIG::GUEST
	{
		import core.events.Event;
		import core.events.EventDispatcher;
		import core.events.IOErrorEvent;
		import core.events.ProgressEvent;
		import core.net.Socket;
	}
	
	[Event(name="connect", type="flash.events.Event")]
	[Event(name="close", type="flash.events.Event")]
	[Event(name="ioError", type="flash.events.IOErrorEvent")]
	[Event(name="crash", type="potato.designer.net.Connection")]
	/**
	 * 连接控制器。使用该对象进行网络通讯。
	 * <br>消息结构： pkgLength:uint, typeCode:uint, [type:String,] msgIndex:uint, answerIndex:uint, data:Object
	 * <br>pkgLength:消息除了pkgLength所占空间外剩余的长度
	 * <br>typeCode:类型的短代码。每个短代码对应了一个类型的完整路径。注意，对于发送和接收同样的type，其短代码是不同的。
	 * <br>type:类型的完整路径。如果第一次使用一个类型，将为其指定一个短代码，并在消息中附加完整路径
	 * <br>msgIndex:消息的index。注意一个消息如果不需要应答，其index固定为0
	 * <br>answerIndex:指定该消息是对另一个消息的应答。当此值为0时说明其不应答任何消息，而是一条广播消息
	 * @author Just4test
	 */
	public class Connection extends EventDispatcher
	{
		/**连接崩溃时派发*/
		public static const EVENT_CRASH:String = "crash";
		
		protected var _socket:Socket;
		
		
		/**
		 *指定消息目标。所有广播消息都将被派发到指定的目标对象上。这并不包括控制事件。如果不指定该目标，消息将被派发到Connection自身。
		 */
		public var messageTarget:EventDispatcher;
		
		CONFIG::GUEST
		{
			protected var _remoteAddress:String;
			protected var _remotePort:int;
		}
		
		/**
		 *指示还未收到的包的长度 
		 */
		protected var _packageLength:uint;
		
		/**
		 *需要应答的消息index与应答句柄映射表 
		 */
		protected var _callbackMap:Object;
		/**
		 *指示下一个需要应答消息的index 
		 */
		protected var _nextCallbackIndex:uint;
		
		
		/**
		 *发送用的类型-短代码映射表 
		 */
		protected var _sendType2Code:Object;
		/**
		 *指示下一个可用的发送用短代码 
		 */
		protected var _nextSendTypeIndex:uint;
		
		
		
		/**
		 *接收用的短代码-类型映射表 
		 */
		protected var _receiveCode2Type:Vector.<String>;
		
		/**
		 * 创建连接控制器
		 * @param socket 如果需要控制一个已经存在的Socket，则传入此Socket对象。否则将自己创建一个Socket。
		 * 
		 */		
		public function Connection(socket:Socket = null)
		{
			_socket = socket || new Socket;
			
			if(_socket.connected)
			{
				initSocket();
			}
		}
		
		
		
		protected function initSocket():void
		{
			_socket.addEventListener(Event.CLOSE, closeHandler);
			_socket.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			_socket.addEventListener(ProgressEvent.SOCKET_DATA, dataHandler);
			
			//连接建立后才创建，以免之前断掉的连接污染本次
			_sendType2Code = new Object;
			_nextSendTypeIndex = 0;
			_receiveCode2Type = new Vector.<String>;
			_callbackMap = new Object;
			_nextCallbackIndex = 1;
		}
		
		public function connect(host:String, port:int):void
		{
			if(!_socket.connected)
			{
				_socket.connect(host, port);
				_packageLength = 0;
				_socket.addEventListener(Event.CONNECT, connectHandler);
				_socket.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			}
			
			
			CONFIG::GUEST
			{
				_remoteAddress = host;
				_remotePort = port;
			}
		}
		
		/**
		 *发送一条消息 
		 * @param type 消息类型
		 * @param data 消息数据体
		 * @param callbackHandle 指定应答回调方法。如果指定此方法，则消息的接收方可以对此消息进行应答，应答消息由回调方法处理。
		 */
		public function send(type:String, data:* = null, callbackHandle:Function = null):void
		{
			actualSend(type, data, callbackHandle, 0);
		}
		
		public function answer(type:String, data:*, callbackHandle:Function, msg:Message):void
		{
			if(!msg.answerable)
			{
				throw new Error("无法应答一个不需要应答的消息，或者多次应答同一条消息");
			}
			actualSend(type, data, callbackHandle, msg._index);
			msg._index = 0;
		}
		
		protected function actualSend(type:String, data:*, callbackHandle:Function, answerIndex:uint):void
		{
			//encode
			var ba:ByteArray = new ByteArray;
			//写入type
			if(undefined === _sendType2Code[type])
			{
				ba.writeUnsignedInt(_nextSendTypeIndex);
				ba.writeUTF(type);
				_sendType2Code[type] = _nextSendTypeIndex;
				_nextSendTypeIndex += 1;
			}
			else
			{
				ba.writeUnsignedInt(_sendType2Code[type]);
			}
			//写入index
			var index:uint;
			if(callbackHandle is Function)
			{
				index = _nextCallbackIndex;
				_callbackMap[index] = callbackHandle;
				_nextCallbackIndex += 1;
			}
			ba.writeUnsignedInt(index);
			//写入answerIndex
			ba.writeUnsignedInt(answerIndex);
			//写入数据
			ba.writeObject(data);
			
			_socket.writeUnsignedInt(ba.length);
			_socket.writeBytes(ba);
			_socket.flush();
			
			CONFIG::DEBUG{
				var traceStr:String;
				if(answerIndex)
				{
					traceStr = "[Connection] 发送对消息号 " + answerIndex + " 的应答[" + type + "]";
				}
				else
				{
					traceStr = "[Connection] 发送广播消息[" + type + "]";
				}
				if(index)
				{
					traceStr += "，并请求应答，请求消息号 " + index;
				}
				else
				{
					
				}
				trace(traceStr);
			}
		}
		
		/**
		 *关闭连接 
		 * 
		 */
		public function close():void
		{
			_socket.close();
			_socket.removeEventListener(Event.CONNECT, connectHandler);
			_socket.removeEventListener(Event.CLOSE, closeHandler);
			_socket.removeEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			_socket.removeEventListener(ProgressEvent.SOCKET_DATA, dataHandler);
		}
		
		public function get connected():Boolean
		{
			return _socket.connected;
		}
		
		
		
		/////////////////////////////////////////////////////////////////
		
		protected function connectHandler(e:Event):void
		{
			CONFIG::DEBUG{trace("[Connection] 连接已经建立!");}
			initSocket();
			dispatchEvent(e);
		}
		
		protected function closeHandler(e:Event):void
		{
			CONFIG::DEBUG{trace("[Connection] 远端切断了连接");}
			_packageLength = 0;
			dispatchEvent(e);
		}
		
		protected function errorHandler(e:Event):void
		{
			CONFIG::DEBUG{trace("[Connection] 发生错误");}
			CONFIG::DEBUG{trace(e);}
			dispatchEvent(e);
			
			if(!_socket.connected)
			{
				_socket.close();//AVM的BUG，如果开始连接后没有连接成功，将占用最大连接数。需要用close()清除。
			}
		}
		
		protected function dataHandler(e:Event):void
		{
			while(_socket.bytesAvailable)
			{
				try
				{
					if(!_packageLength)
					{
						if(_socket.bytesAvailable >= 4)
						{
							_packageLength = _socket.readUnsignedInt();
						}
						else
						{
							return;
						}
					}
					
					if(_socket.bytesAvailable < _packageLength)
					{
						return;
					}
					
					var typeCode:uint = _socket.readUnsignedInt();
					if(typeCode == _receiveCode2Type.length)
					{
						_receiveCode2Type[typeCode] = _socket.readUTF();
					}
					
					var type:String = _receiveCode2Type[typeCode];
					var index:uint = _socket.readUnsignedInt();
					var answerIndex:uint = _socket.readUnsignedInt();
					var data:* = _socket.readObject();
				} 
				catch(error:Error) 
				{
					CONFIG::DEBUG{trace("[Connection] 协议错误，连接崩溃。这可能是因为您连接到了一个非Connection管理的Socket，或者Connection版本不兼容。", error);}
					dispatchEvent(new Event(EVENT_CRASH));
					close();
				}
			
				var msg:Message;
				msg = new Message(this, type, data);
				msg._index = index;
				if(answerIndex)
				{
					var answerHandle:Function = _callbackMap[answerIndex];
					if(answerHandle is Function)
					{
						CONFIG::DEBUG{trace("[Connection] 收到对消息号", answerIndex, "的应答[" + type + "]");}
						answerHandle(msg);
						delete _callbackMap[answerIndex];
					}
					else
					{
						CONFIG::DEBUG{trace("[Connection] 收到对消息号", answerIndex, "的应答[" + type + "]，但对应的原始消息未找到。");}
					}
				}
				else
				{
					CONFIG::DEBUG{trace("[Connection] 收到消息 [" + type + "]");}
					(messageTarget || this).dispatchEvent(msg);
				}
				_packageLength = 0;
			}
			
		}
		
		CONFIG::HOST
		{
			public function get localAddress():String
			{
				return _socket.localAddress;
			}
			
			public function get localPort():int
			{
				return _socket.localPort;
			}
			
		}
		
		public function get remoteAddress():String
		{
			CONFIG::HOST{return _socket.remoteAddress;}
			CONFIG::GUEST{return _remoteAddress;}
		}
		
		public function get remotePort():int
		{
			CONFIG::HOST{return _socket.remotePort;}
			CONFIG::GUEST{return _remotePort;}
		}
	}
}