package
{
	
	import core.display.DisplayObjectContainer;
	import core.display.Stage;
	
	import potato.designer.framework.DataCenter;
	import potato.designer.framework.DesignerEvent;
	import potato.designer.framework.EventCenter;
	import potato.designer.framework.PluginManager;
	import potato.ui.TextInput;
	import potato.ui.UIGlobal;
	
	public class Main extends DisplayObjectContainer
	{
//		protected var _domain:Domain;
//		protected var _connection:Connection;
		
		static protected var _instance:Main;
		
		public var textHost:TextInput;
		
		public function Main(arg:String = null)
		{
//			_instance = this;
//			
//			var res:Res = new Res();
//			//			res.addEventListener(HttpEvent.RES_LOAD_COMPLETE, onLoaded);
//			res.appendCfg("rcfg.txt", true);
//			
//			var connectHelper:ConnectHelper = new ConnectHelper;
//			addChild(connectHelper);
			DataCenter.loadWorkSpace("designer");
			
			textHost = new TextInput("", 300, 30, UIGlobal.defaultFont, 32, 0xffffffff);
			textHost.text = "123123123123";
			Stage.getStage().addChild(textHost);
			
			EventCenter.addEventListener(EventCenter.EVENT_LOG, log2textHost);
			function log2textHost(event:DesignerEvent):void
			{
				textHost.text = event.data;
			}
			
			EventCenter.addEventListener(PluginManager.EVENT_PLUGIN_INSTALLED, loadPluginWhenLoaded);
			PluginManager.scan();
			
			
			EventCenter.addEventListener(PluginManager.EVENT_PLUGIN_START, startHandler);
		}
		
		protected function loadPluginWhenLoaded(e:DesignerEvent):void
		{
			PluginManager.startPlugin(e.data.id);
		}
		
		protected function startHandler(e:DesignerEvent):void
		{
			
			var num:int = 1000000 * Math.random();
		}
		
//		/**
//		 * 载入项目代码
//		 * <br>使用部分设计器专用代码覆盖项目代码中的同名类，以实现高级功能。 
//		 * @param fileName
//		 * 
//		 */
//		public function load(fileName:String):void
//		{
//			if(_domain)
//			{
//				unload();
//			}
//			
//			//载入覆盖代码
//			var resDomain:Domain = new Domain();
//			resDomain.load(Const.DESIGNER_OVERRIDE_FILE);
//			
//			//载入项目代码
//			_domain = new Domain(resDomain);
//			_domain.load(fileName);
//			
//		}
//		
//		/**
//		 *卸载所有类，并保证内存得到完全回收。
//		 */
//		public function unload():void
//		{
//			var stage:Stage = Stage.getStage();
//			while(stage.numChildren)
//			{
//				stage.removeChildAt(0);
//			}
//			
//			stage.removeEventListeners();
//			
//			_domain = null;
//		}
//		
//		public function setConnection(connection:Connection):void
//		{
//			while(Stage.getStage().numChildren)
//			{
//				Stage.getStage().removeChildAt(0);
//			}
//			
//			if(_connection)
//			{
//				_connection.removeEventListeners();
//			}
//			
//			_connection = connection;
//			
//			//注册所有网络消息侦听
//			_connection.addEventListener(NetConst.S2C_REQ_DESCRIBE_TYPE, onReqDescribeTypeHandler);
//			
//			//通知服务端客户端准备好，可以开始初始化过程
//			
//			connection.send(NetConst.C2S_HELLO, "hello world!");
//			log("客户端已经准备好。");
//			
//		}
//		
//		protected function onReqDescribeTypeHandler(e:Message):void
//		{
//			try
//			{
//				var obj:Object = getDefinitionByName(e.data as String);
//				if(obj is Class)
//				{
//					e.answer("", describeType(obj));
//				}
//				else
//				{
//					e.answer("");
//				}
//			} 
//			catch(error:Error) 
//			{
//				e.answer("");
//			}
//		}
//
//		public static function get instance():Main
//		{
//			return _instance;
//		}
//
//		public function get connection():Connection
//		{
//			return _connection;
//		}
//		
		
	}
}