package potato.designer.plugin.window
{
	import mx.core.UIComponent;
	
	import spark.layouts.supportClasses.LayoutBase;

	[Bindable]
	public class WindowData
	{
		/**
		 *窗口标题 
		 */
		public var title:String;
		
		/**
		 *窗口布局 
		 */
		public var layout:LayoutBase;
		
		/**
		 *窗口组件列表 
		 */
		public var components:Vector.<UIComponent>;
		
		/**
		 *窗口初始宽度 
		 */
		public var width:int;
		
		/**
		 *窗口初始高度 
		 */
		public var height:int;
		
		/**
		 *指定是否自动设置窗口尺寸。 如果此值为true，则忽略初始宽高，并且用户不可以手动更改窗口尺寸。
		 */
		public var autoSize:Boolean;
		
		
		internal var _refreshFunction:Function;
		
		public function refresh():void
		{
			_refreshFunction && _refreshFunction();
		}
		
		internal var _closeFunction:Function;
		public function close():void
		{
			_closeFunction && _closeFunction();
		}
	}
}