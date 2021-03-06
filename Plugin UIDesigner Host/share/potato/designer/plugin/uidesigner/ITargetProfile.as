package potato.designer.plugin.uidesigner
{
	/**
	 *组件描述文件接口
	 * <br>组件描述文件接口是必要的，因为它定义了访问子代描述文件的方法。
	 * <br>组件描述文件和解释器配套使用。如果您重新定义了本接口的一个实现，请确保您提供了能够理解它的解释器。
	 * @author Just4test
	 * 
	 */
	public interface ITargetProfile
	{
		/**获取子对象的描述文件。
		 * <br>禁止返回null。如果对象没有子对象，请返回0长数组
		 */
		function get children():Vector.<ITargetProfile>;
	}
}