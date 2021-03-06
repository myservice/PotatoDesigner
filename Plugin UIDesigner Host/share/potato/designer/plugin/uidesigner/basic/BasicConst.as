package potato.designer.plugin.uidesigner.basic
{
	public class BasicConst
	{
		/**建议值文件所在位置*/
		public static const SUGGEST_FILE_PATH:String = "suggest.json";
		
		
		/**解释器数据中类描述文件的key*/
		public static const INTERPRETER_CLASS_TYPE_PROFILE:String = "INTERPRETER_CLASS_TYPE_PROFILE";
		/**解释器数据中组件描述文件的key*/
		public static const INTERPRETER_COMPONENT_PROFILE:String = "INTERPRETER_COMPONENT_PROFILE";
		
		/**编译器向解释器请求已经注册的type表。table[typeName] = className*/
		public static const S2C_REQ_TYPE_TABLE:String = "S2C_REQ_TYPE_TABLE";
		
		/**向解释器推送类描述文件映射表*/
		public static const S2C_PUSH_CLASS_TABLE:String = "S2C_PUSH_CLASS_TABLE";
		
		/**向解释器注册单个类描述文件*/
		public static const S2C_REG_CLASS:String = "S2C_REG_CLASS";
		
		
		
		/**设置指定对象的属性。data=[path, accessor]*/
		public static const C2S_SET_ACCESSOR:String = "C2S_SET_ACCESSOR";
		
		
		
	}
}