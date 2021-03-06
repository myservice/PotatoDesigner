package potato.designer.plugin.uidesigner
{
	public class DesignerConst
	{
		
		/**
		 * 设置焦点和选中组件
		 * <br>msg = [foldPath, focusIndex]
		 */
		public static const C2S_SET_FOLD_FOCUS:String = "C2S_SET_FOLD_FOCUS";
		/**
		 * 执行默认操作
		 * <br>msg = path
		 */
		public static const C2S_DO_DEFAULT_ACTION:String = "C2S_DO_DEFAULT_ACTION";
		/**
		 * 移动目标显示对象
		 * <br>msg = [path, newX, newY]
		 */
		public static const C2S_DISPLAYOBJ_MOVE:String = "C2S_DISPLAYOBJ_MOVE";
		/**
		 * 改变目标显示对象的尺寸
		 * <br>msg = [path, newX, newY]
		 */
		public static const C2S_DISPLAYOBJ_RESIZE:String = "C2S_DISPLAYOBJ_RESIZE";
		
		
		/**请求指定的类描述*/		
		public static const S2C_REQ_DESCRIBE_TYPE:String = "UID_S2C_REQ_DESCRIBE_TYPE";
		/**初始化UIDesigner
		 * <br>这是一个异步方法。
		 */
		public static const S2C_INIT:String = "UID_S2C_INIT";
		
		
		/**通知客户端刷新组件树
		 */
		public static const S2C_REFRESH:String = "UID_S2C_REFRESH";
		
		/**
		 *组件更新，同时焦点可能也已经改变
		 * <br>客户端派发此事件时，替身树已经重绘完成。
		 */
		public static const UPDATE:String = "UID_UPDATE";
		
		/**更新客户端组件树
		 * <br>msg = [rootTargetProfile, foldPath, focusIndex]
		 */
		public static const S2C_UPDATE:String = "UID_S2C_UPDATE";
		
		/**
		 *选中的组件已经改变 
		 */
		public static const FOLD_FOCUS_CHANGED:String = "FOLD_FOCUS_CHANGED";
		/**通知客户端选中的组件已经改变
		 * <br>msg = [foldPath, focusIndex]
		 */
		public static const S2C_FOLD_FOCUS_CHANGED:String = "S2C_FOLD_FOCUS_CHANGED";
		
//		/**向宿主端发出改变选中组件的请求
//		 * <br>msg = [foldPath, focusIndex]
//		 */		
//		public static const C2S_CHANGE_FOCUS:String = "C2S_CHANGE_FOCUS";
		
		public static const PLUGIN_NAME:String = "UIDesigner";
		
		
		
		
		public static function getShortClassName(fullName:String):String
		{
			return fullName.split("::").pop();
		}
		
		CONFIG::HOST
		{
			/**
			 * 事件：生成组件配置文件
			 * <br>这是一个同步事件。由于每次添加/删除/修改组件（比如拖动组件位置）都会重新生成组件配置文件并重新构建组件树，因此生成组件配置文件的过程需要非常快。
			 * <br>这个事件将附带一个Object，即目标配置文件。各个编译器需要监听这个事件，并为Object添加属性。添加的属性必须可以序列化。
			 */
			public static const EVENT_MAKE_COMPONENT_PROFILE:String = "UID_EVENT_MAKE_COMPONENT_PROFILE";
			
			
			/**
			 *事件：导出发布版本
			 * <br>生成一个为发布优化的组件配置文件版本。此版本可能为运行时优化了效率，或者针对特定环境进行导出。
			 * 如果某个编译器不涉及为发布优化的功能，以 EVENT_MAKE_COMPONENT_PROFILE 方式响应此事件即可。
			 * <br>这是一个异步事件。允许编译器异步执行（比如与Guest端通讯）甚至导出失败。
			 * <br>data:[target:Object, multiLock:MultiLock]
			 */
			public static const EVENT_EXPORT_RELEASE_BUILD:String = "UID_EVENT_EXPORT_RELEASE_BUILD";
			/**
			 *导出发行版成功 
			 */
			public static const EVENT_EXPORT_OK:String = "UID_EVENT_EXPORT_OK";
			/**
			 * 导出发行版失败
			 */
			public static const EVENT_EXPORT_FAILED:String = "UID_EVENT_EXPORT_FAILED";
			
			/**单击大纲条目，执行选中操作*/
			public static const OUTLINE_ITEM_CLICK:String = "OUTLINE_ITEM_CLICK";
			
			/**双击大纲条目，执行展开操作*/
			public static const OUTLINE_ITEM_DOUBLE_CLICK:String = "OUTLINE_ITEM_DOUBLE_CLICK";
			
			/**在大纲条目上右键删除*/
			public static const OUTLINE_ITEM_DELETE:String = "OUTLINE_ITEM_DELETE";
		}
	}
}