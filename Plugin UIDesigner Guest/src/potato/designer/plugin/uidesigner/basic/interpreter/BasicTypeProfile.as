package potato.designer.plugin.uidesigner.basic.interpreter
{
	public class BasicTypeProfile
	{
		protected var _typeName:String;
		protected var _converter:Function;
		protected var _isSerializable:Boolean;
		protected var _className:String;
		
		public function BasicTypeProfile(typeName:String, converter:Function, isSerializable:Boolean = false, className:String = null)
		{
			_typeName = typeName;
			_converter = converter;
			_isSerializable = isSerializable;
			_className = className;
		}
		
		
		
		public function get typeName():String
		{
			return _typeName;
		}

		public function get converter():Function
		{
			return _converter;
		}

		public function get isSerializable():Boolean
		{
			return _isSerializable;
		}

		public function get className():String
		{
			return _className;
		}


	}
}