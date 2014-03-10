package
{
	import flash.utils.describeType;
	import flash.utils.getDefinitionByName;
	
	import core.display.DisplayObjectContainer;
	import core.display.Stage;
	import core.system.Domain;
	
	import potato.designer.net.Connection;
	import potato.designer.net.MessageEvent;
	import potato.designer.net.NetConst;
	import potato.designer.ui.ConnectHelper;
	import potato.res.Res;
	
	public class Main extends DisplayObjectContainer
	{
		protected var _domain:Domain;
		protected var _connection:Connection;
		
		static protected var _instance:Main;
		
		public function Main(arg:String = null)
		{
			_instance = this;
			
			var res:Res = new Res();
			//			res.addEventListener(HttpEvent.RES_LOAD_COMPLETE, onLoaded);
			res.appendCfg("rcfg.txt", true);
			
			var connectHelper:ConnectHelper = new ConnectHelper;
			addChild(connectHelper);
			
		}
		
		public function load(fileName:String):void
		{
			if(_domain)
			{
				return;
			}
			_domain = new Domain(Domain.currentDomain);
			_domain.load(fileName);
			
		}
		
		/**
		 *卸载所有类，并保证内存得到完全回收。 
		 * 
		 */
		public function unload():void
		{
			var stage:Stage = Stage.getStage();
			while(stage.numChildren)
			{
				stage.removeChildAt(0);
			}
			
			stage.removeEventListeners();
			
			_domain = null;
		}
		
		public function setConnection(connection:Connection):void
		{
			while(Stage.getStage().numChildren)
			{
				Stage.getStage().removeChildAt(0);
			}
			
			if(_connection)
			{
				_connection.removeEventListeners();
			}
			
			_connection = connection;
			
			//注册所有网络消息侦听
			_connection.addEventListener(NetConst.S2C_REQ_DESCRIBE_TYPE, onReqDescribeTypeHandler);
			
			//通知服务端客户端准备好，可以开始初始化过程
			
			connection.send(NetConst.C2S_HELLO, "hello world!");
			
		}
		
		protected function onReqDescribeTypeHandler(e:MessageEvent):void
		{
			try
			{
				var obj:Object = getDefinitionByName(e.data as String);
				if(obj is Class)
				{
					e.answer("", describeType(obj));
				}
				else
				{
					e.answer("");
				}
			} 
			catch(error:Error) 
			{
				e.answer("");
			}
		}

		public static function get instance():Main
		{
			return _instance;
		}
		
		
	}
}