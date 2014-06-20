package potato.designer.plugin.uidesigner
{
	
	import flash.events.Event;
	
	import mx.collections.ArrayList;
	
	import potato.designer.framework.DesignerEvent;
	import potato.designer.framework.EventCenter;
	import potato.designer.framework.IPluginActivator;
	import potato.designer.framework.PluginInfo;
	import potato.designer.plugin.guestManager.Guest;
	import potato.designer.plugin.guestManager.GuestManagerHost;
	import potato.designer.plugin.uidesigner.basic.compiler.BasicCompiler;
	import potato.designer.utils.MultiLock;
	
	/**
	 *管理编译器的Host端
	 * <br>提供两个窗口作为Host端UI。这两个窗口均为纵向布局。习惯上，窗口0显示组件类型视图和大纲视图，窗口1显示属性视图。
	 * <br>提供打包、传输组件描述文件的方式
	 * <br>提供控制组件替身的方式
	 * @author Administrator
	 * 
	 */
	public class UIDesignerHost implements IPluginActivator
	{		
		/**组件视图数据提供程序*/
		protected static var _componentTypeViewDataProvider:ArrayList;
		
		/**大纲视图数据提供程序*/
		protected static var _outlineTree:XML;
		
		/**添加组件菜单数据提供程序*/
		protected static var _componentTypeCreaterDataProvider:ArrayList;
		
		/**插件注册方法*/
		public function start(info:PluginInfo):void
		{
			_componentTypeViewDataProvider = new ArrayList;
			_outlineTree = <root/>;
			_componentTypeCreaterDataProvider = new ArrayList;
			
			clearStage();
			
			//初始化UI
			ViewController.init(_componentTypeViewDataProvider, _outlineTree, _componentTypeCreaterDataProvider);
			
			//初始化基础编译器
			BasicCompiler.init(info);
			
			//初始化客户端
			EventCenter.addEventListener(GuestManagerHost.EVENT_GUEST_PLUGIN_ACTIVATED, guestPluginActivatedHandler);
			EventCenter.addEventListener(GuestManagerHost.EVENT_GUEST_CONNECTED, guestConnectedHandler);
			for each(var guest:Guest in GuestManagerHost.getGuestsWithPlugin(DesignerConst.PLUGIN_NAME))
			{
				initGuest(guest);
			}
			
			info.started();
			
		}
		
		protected function guestPluginActivatedHandler(event:DesignerEvent):void
		{
			if(DesignerConst.PLUGIN_NAME == event.data[1])
			{
				initGuest(event.data[0]);
			}
		}
		
		protected function guestConnectedHandler(event:DesignerEvent):void
		{
			if(Guest(event.data).isPluginActived(DesignerConst.PLUGIN_NAME))
			{
				initGuest(event.data);
			}
		}
		
		protected function initGuest(guest:Guest):void
		{
			var lock:MultiLock = new MultiLock;
			lock.addEventListener(MultiLock.EVENT_UNLOCKED, lockHandler);
			lock.addEventListener(MultiLock.EVENT_DEAD, lockHandler);
			
			for (var i:int = 0; i < compilerList.length; i++) 
			{
				if(compilerList[i].initGuest(guest, lock))
					break;
			}
			
			if(lock.isFree)
			{
				logf("[{0}] 客户端[{1}]初始化完毕。", DesignerConst.PLUGIN_NAME, guest.id);
			}
			
			function lockHandler(event:Event):void
			{
				lock.removeEventListener(MultiLock.EVENT_UNLOCKED, lockHandler);
				lock.removeEventListener(MultiLock.EVENT_DEAD, lockHandler);
				
				if(MultiLock.EVENT_UNLOCKED == event.type)
				{
					logf("[{0}] 客户端[{1}]初始化完毕。", DesignerConst.PLUGIN_NAME, guest.id);
				}
				else
				{
					logf("[{0}] 客户端[{1}]初始化失败：{2}", DesignerConst.PLUGIN_NAME, guest.id, MultiLock(event.target).locks);
				}
			}
		}
	
		
		//////////////////////////////////////////////////////////////////////////////
		
		/**编译器队列*/
		public static const compilerList:Vector.<ICompiler> = new Vector.<ICompiler>;
		
		
		/**编译器配置文件树的根*/
		protected static var _rootCompilerProfile:CompilerProfile;
		
		/**展开路径*/
		protected static var _foldPath:Vector.<uint>;
		/**焦点索引*/
		protected static var _focusIndex:int;
		
		
//		protected static var _multiLock:MultiLock;
//		protected static var _componentProfile:Object;
		
		/**组件类型映射表*/
		protected static const _componentTypeTable:Object = {};
		
		
		
		////////////////////////////////////////////////////////////////////////////
		
		/**
		 *清理所有已经存在的组件，并初始化 
		 * 
		 */
		public static function clearStage():void
		{
			_rootCompilerProfile = null;
			_foldPath = new Vector.<uint>;
			_focusIndex = -1;
		}
		
		public static function get exportResult():Object
		{
			return null;
		}
		
		/**
		 *检查编译器是否锁定。当导出发布版本未完成时，编译器锁定。此时不应对组件配置有任何修改。
		 */
//		public static function get isLocking():Boolean
//		{
//			return !_multiLock;
//		}
		
		
		
		
		/**
		 *注册组件类型 
		 * @param name 组件名
		 * @param isContainer 组件是否是容器。这决定了组件能否展开并插入子组件
		 * @param icon 为组件指定图标
		 * 
		 */
		public static function regComponentType(name:String, isContainer:Boolean, icon:* = null):void
		{
			_componentTypeTable[name] = new ComponentType(name, isContainer, icon);
			_componentTypeViewDataProvider.addItem(_componentTypeTable[name]);
		}
		
		/**
		 *移除组件类型 
		 * @param name 组件名
		 * @return 如果成功移除了组件，返回true。如果本不存在该名称的组件，返回false
		 * 
		 */
		public static function removeComponentType(name:String):Boolean
		{
			if(_componentTypeTable[name])
			{
				_componentTypeViewDataProvider.removeItem(_componentTypeTable[name]);
				delete _componentTypeTable[name];
				return true;
			}
			return false;
		}
		
		/**
		 *注册组件类型创建器菜单项
		 * <br>在设计器UI中，组件视图的左上角有一个添加组件下拉菜单。使用此方法注册新的菜单项
		 * @param label 菜单项的标签
		 * @param func 点击菜单项后调用的方法
		 * 
		 */
		public static function regComponentTypeCreater(label:String, func:Function):void
		{
			_componentTypeCreaterDataProvider.addItem({label:label, func:func, toString:function():String{return label}});
		}
		
		/**
		 * 移除组件类型创建器菜单项
		 * @param label 菜单项的标签
		 * 
		 */
		public static function removeComponentTypeCreater(label:String):void
		{
			for(var i:int = 0; i < _componentTypeCreaterDataProvider.length; i++)
			{
				var obj:Object = _componentTypeCreaterDataProvider.getItemAt(i);
				if(obj.label == label)
				{
					delete _componentTypeCreaterDataProvider.removeItem(obj)
				}
			}
		}
		
//		protected static function 
		
		
		/**
		 *刷新客户端组件树
		 * <br>当属性更改或者向组件树添加了新组件后调用这个方法。
		 * <br>这个方法将先派发EVENT_MAKE_COMPONENT_PROFILE事件，以创建组件配置文件；
		 * <br>然后将组件配置文件传输至客户端，指示其刷新设计舞台。
		 */
		public static function updateGuest():void
		{
			if(_rootCompilerProfile)
				update(_rootCompilerProfile);
			
			for each(var i:Guest in GuestManagerHost.getGuestsWithPlugin(DesignerConst.PLUGIN_NAME))
			{
				i.send(DesignerConst.S2C_UPDATE, [_rootCompilerProfile && _rootCompilerProfile.targetProfile, _foldPath, _focusIndex]);
			}
		}
		
		
		public static function update(profile:CompilerProfile):void
		{
			for (var i:int = 0; i < profile.children.length; i++) 
			{
				update(profile.children[i]);
			}
			
			
			for (var j:int = 0; j < compilerList.length; j++) 
			{
				if(compilerList[j].update(profile))
					break;
			}
			
		}
		
		/**
		 *导出发行版
		 * <br>此方法派发 EVENT_EXPORT_RELEASE_BUILD 事件以调用编译器生成发行版组件。
		 * 
		 */
		/*
		public static function exportReleaseBuild():void
		{
			_multiLock = new MultiLock;
			EventCenter.dispatchEvent(new DesignerEvent(DesignerConst.EVENT_EXPORT_OK, [_componentProfile, _multiLock]));
			if(!_multiLock.isFree)
			{
				finishExport();
			}
			else
			{
				_multiLock.addEventListener(MultiLock.EVENT_DEAD, multiLockHandler);
				_multiLock.addEventListener(MultiLock.EVENT_UNLOCKED, multiLockHandler);
			}
		}
		
		protected static function multiLockHandler(event:Event):void
		{
			_multiLock.removeEventListener(MultiLock.EVENT_DEAD, multiLockHandler);
			_multiLock.removeEventListener(MultiLock.EVENT_UNLOCKED, multiLockHandler);
			
			switch(event.type)
			{
				case MultiLock.EVENT_DEAD:
				{
					finishExport();
					break;
				}
				case MultiLock.EVENT_UNLOCKED:
				{
					EventCenter.dispatchEvent(new Event(DesignerConst.EVENT_EXPORT_FAILED));
					break;
				}
					
				default:
				{
					throw new Error("内部错误");
					break;
				}
			}
		}
		
		
		protected static function finishExport():void
		{
			_multiLock = null;
			EventCenter.dispatchEvent(new Event(DesignerConst.EVENT_EXPORT_OK));
		}
		*/
		
		/**
		 *在当前路径下添加组件 
		 * @param type
		 * 
		 */
		public static function addComponent(type:String):void
		{
			var cp:CompilerProfile = new CompilerProfile(type);
			
			for (var i:int = 0; i < compilerList.length; i++) 
			{
				if(compilerList[i].addTarget(cp))
					break;
			}
			
			var folder:CompilerProfile = getCompilerProfileAtPath(_rootCompilerProfile, _foldPath);
			
			if(folder)
			{
				folder.addChildAt(cp, _focusIndex);
			}
			else
			{
				_rootCompilerProfile = cp;
			}
			
			updateGuest();
			
			
		}
		
		/**
		 *获取编译器配置文件树中指定的目标
		 * @param cp 编译器配置文件树
		 * @param foldPath 展开路径。
		 * @param focusIndex 焦点索引。如果指定为-1则说明没有选中任何对象。 
		 * @return 
		 * 
		 */
		protected static function getCompilerProfileAtPath(cp:CompilerProfile, foldPath:Vector.<uint>, focusIndex:int = -1):CompilerProfile
		{
			while(foldPath.length)
			{
				var index:int = foldPath.shift();
				if(cp.children.length <= index)
					return null;
				cp = cp.children[index];
				
			}
			
			if(-1 != focusIndex)
			{
				if(cp.children.length <= focusIndex)
					return null;
				cp = cp.children[focusIndex];
			}
			
			return cp;
		}
		
		
	}
}


import potato.designer.plugin.uidesigner.UIDesignerHost;

/**
 *组件类型 
 * @author Just4test
 * 
 */
class ComponentType
{
	public var name:String;
	public var isContainer:Boolean;
	public var icon:*;
	
	public function add():void
	{
		UIDesignerHost.addComponent(name);
	}
	
	function ComponentType(name:String, isContainer:Boolean, icon:* = null)
	{
		this.name = name;
		this.isContainer = isContainer;
		this.icon = icon;
	}
}