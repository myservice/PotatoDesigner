package potato.designer.plugin.fileSync 
{
	
	
	import flash.events.TimerEvent;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	import potato.designer.framework.DataCenter;
	import potato.designer.framework.DesignerEvent;
	import potato.designer.framework.EventCenter;
	import potato.designer.framework.PluginInfo;
	import potato.designer.net.Message;

	CONFIG::HOST
	{
		import flash.filesystem.File;
		import flash.filesystem.FileMode;
		import flash.filesystem.FileStream;
		import flash.utils.Dictionary;
		
		import potato.designer.framework.EventCenter;
		import potato.designer.plugin.guestManager.Guest;
		import potato.designer.plugin.guestManager.GuestManagerHost;
	}
	
	CONFIG::GUEST
	{
		import core.filesystem.File;
		import core.filesystem.FileInfo;
		
		import potato.designer.plugin.guestManager.GuestManagerGuest;
	}
	
	public class Sync
	{
		public static const PLUGIN_NAME:String = "FileSync";
		
		/**创建远程Sync对象*/
		public static const CREATE_REMOTE_SYNC:String = "CREATE_REMOTE_SYNC";
		
		/**没有文件会被同步。*/
		public static const DIRECTION_NONE:String = "DIRECTION_NONE";
//		/**远程目录是源目录，本地目录是目标目录。*/
//		public static const DIRECTION_TO_LOCAL:String = "DIRECTION_TO_LOCAL";
		/**本地目录是源目录，远程目录是目标目录。*/
		public static const DIRECTION_TO_REMOTE:String = "DIRECTION_TO_REMOTE";
//		/**双向同步*/
//		public static const DIRECTION_TWO_WAY:String = "DIRECTION_TWO_WAY";
		
		/**
		 *模式：默认
		 * <br>如果发生冲突，将会跳过。
		 * <br>同步模式为TO_LOCAL和TO_REMOTE时，目标目录的多余文件不会被删除。
		 * <br>同步模式为TWO_WAY时，发生删除操作时，什么也不做
		 */
		public static const MODE_DEFAULT:String = null;
		
		/**
		 * 模式：严格
		 * <br>同步模式为TO_LOCAL和TO_REMOTE时：
		 * <br>当发生文件冲突时，将覆盖目的文件。将删除目的文件夹中存在，而源文件夹中不存在的文件。
		 * <br>同步模式为TWO_WAY时：
		 * <br>将同步删除操作。如果发生文件冲突，则使用“较新的文件”覆盖“较旧的文件”。本次修改时间离上次修改时间较长的文件被认为较新。
		 */
		public static const MODE_STRICT:String = "MODE_STRICT";
		
		
		/**本地及远程目录都是易变目录*/
		public static const CHANGELESS_NONE:String = "CHANGELESS_NONE";
		/**本地目录是非易变目录*/
		public static const CHANGELESS_LOCAL:String = "CHANGELESS_LOCAL";
		/**远程目录是非易变目录*/
		public static const CHANGELESS_REMOTE:String = "CHANGELESS_REMOTE";
		
		
		/**执行同步操作*/
		protected static const JOB_SYNC:String = "SYNC";
		/**同步操作执行完成的结束指令，主要用于回调*/
		protected static const JOB_SYNC_END:String = "SYNC_END";
		/**执行PUSH操作*/
		protected static const JOB_PUSH:String = "SYNC_PUSH";
		/**执行PULL操作*/
		protected static const JOB_PULL:String = "SYNC_PULL";
		/**执行远程Sync的扫描请求。远程扫描请求应该排队执行，以便队列中正在执行PULL/PUSH等操作后，获取正确的执行结果。*/
		protected static const JOB_REMOTE_SCAN:String = "SYNC_REMOTE_SCAN";
//		protected static const JOB_REMOTE_SYNC:String = "SYNC_REMOTE_SYNC";
		
		protected static var isCreatingRemote:Boolean;
		
		
		
		protected var _id:String;
		protected var _localPath:String;
		protected var _remotePath:String;
		protected var _direction:String;
		protected var _syncSubfolder:Boolean;
		protected var _changeLess:String;
		
		
		/**文件的更改时间表。每次扫描更新这个表*/
		internal var fileMap:Object = {};
		/**文件自上次同步之后的更改时间表。同步之后才更新这个表*/
		internal var lastSyncMap:Object = {};
		/**更改表，来自于fileMap和lastSyncMap中不同的条目
		 * fileMap、lastSyncMap 中均存在但时间不同，则存储[上次同步更改时间，最后更改时间]
		 * fileMap中不存在、lastSyncMap中存在（文件已删除）则存储false
		 * fileMap中存在、lastSyncMap中不存在（文件为新增）则存储最后更改时间
		 */
		internal var changedMap:Object = {};
		protected const jobs:Vector.<SyncJob> = new Vector.<SyncJob>;
		protected var working:Boolean;
		
		protected function addJob(job:SyncJob):void
		{
			jobs.push(job);
			work();
		}
		
		protected function jobDone(...args):void
		{
			var job:SyncJob = jobs.shift();
			log("[Sync] 工序", job.type, "完成", job.path);
			job.callback && job.callback.apply(null, args);
			working = false;
			work();
		}
		
		CONFIG::HOST
		protected var _guest:Guest;
		CONFIG::HOST
		/**
		 * 客户端与syncMap对应表
		 */
		protected static const guestMap:Dictionary = new Dictionary;
		CONFIG::GUEST
		/**
		 * id与Sync对象对应表
		 */
		protected static const syncMap:Object = new Object;
		
		protected var remoteCrated:Boolean;
		
		
		internal static function start(info:PluginInfo):void
		{
			CONFIG::HOST
			{
				for each(var i:Guest in GuestManagerHost.guestList)
				{
					addEventListenerTo(i);
				}
				EventCenter.addEventListener(GuestManagerHost.EVENT_GUEST_CONNECTED,
					function(event:DesignerEvent):void
					{
						addEventListenerTo(event.target);
						
						//测试代码
//						var s:Sync = new Sync(event.data as Guest, "temp", "temp", true, DIRECTION_TO_REMOTE);
//						var timer:Timer = new Timer(1000);
//						timer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent):void
//						{
//							s.sync(function(result:Boolean):void{log("同步结束！", result)});
//						});
//						timer.start();
					});
			}
			
			CONFIG::GUEST
			{
				addEventListenerTo(GuestManagerGuest);
				//测试代码
//				EventCenter.addEventListener(GuestManagerGuest.EVENT_HOST_DISCOVERED, hostDiscoverdHandler);
//				GuestManagerGuest.startHostDiscovery();
//				function hostDiscoverdHandler(event:DesignerEvent):void
//				{
//					if(event.data.length)
//					{
//						GuestManagerGuest.tryConnect(event.data[0]);
//						GuestManagerGuest.stopHostDiscovery();
//					}
//				}
			}
			
			info.started();
			
			function addEventListenerTo(eventDispatcher:*):void
			{
				eventDispatcher.addEventListener(CREATE_REMOTE_SYNC, createRemoteSyncHandler);
				eventDispatcher.addEventListener(JOB_PUSH, msgForwardHandler);
				eventDispatcher.addEventListener(JOB_PULL, msgForwardHandler);
				eventDispatcher.addEventListener(JOB_REMOTE_SCAN, msgForwardHandler);
			}
		}
		
		protected static function createRemoteSyncHandler(msg:Message):void
		{
			log("接收到创建远程Sync对象的请求", msg.data);
			isCreatingRemote = true;
			
			CONFIG::HOST
			{
				new Sync(msg.data[0], msg.data[1], msg.data[2], msg.data[3], msg.data[4], msg.data[5], msg.data[6]);
			}
				
			CONFIG::GUEST
			{
				new Sync(msg.data[0], msg.data[1], msg.data[2], msg.data[3], msg.data[4], msg.data[5]);
			}
			
			isCreatingRemote = false;
			msg.answer("");
			
		}
		
		/**
		 *将同一个客户端/主机端传递过来的相关消息转发给对应的Sync对象 
		 * @param msg
		 * 
		 */
		protected static function msgForwardHandler(msg:Message):void
		{
			CONFIG::HOST
			{
				const syncMap:Object = guestMap[msg.target];
			}
			
			const sync:Sync = syncMap[msg.data[0]];
			
			
			switch(msg.type)
			{
				case JOB_PUSH:
					sync.pushRequestHandler(msg);
					break;
				case JOB_PULL:
					sync.pullRequestHandler(msg);
					break;
				case JOB_REMOTE_SCAN:
					sync.scanRemoteRequestHandler(msg);
					break;
				
				default:
					throw "无法理解消息类型";
			}
		}
		
		CONFIG::HOST
		protected function send(type:String, data:* = null, callbackHandle:Function = null):void
		{
			_guest.send(type, data, callbackHandle);
		}
		
		CONFIG::GUEST
		protected function send(type:String, data:* = null, callbackHandle:Function = null):void
		{
			GuestManagerGuest.send(type, data, callbackHandle);
		}
		
		
		
		CONFIG::HOST
		/**
		 *创建一个同步对象 
		 * @param localPath 本地路径
		 * @param remotePath 远程路径
		 * @param syncSubfolder 是否同步子目录
		 * @param channel
		 * @param direction
		 * @param changeLess
		 * @param id
		 * 
		 */
		public function Sync(guest:Guest, localPath:String, remotePath:String, syncSubfolder:Boolean,
							 direction:String = DIRECTION_NONE, changeLess:String = CHANGELESS_NONE, id:String = null)
		{
			_guest = guest;
			
			id ||= Math.random().toString();
			_id = id;
			guestMap[guest] ||= {};
			guestMap[guest][id] = this;
			_localPath = localPath;
			_remotePath = remotePath;
			_syncSubfolder = syncSubfolder;
			_direction = direction;
			_changeLess = changeLess;
			
			log("创建Sync", guest, localPath, remotePath, syncSubfolder, direction, changeLess, id);
			scanLocal();
			
			if(isCreatingRemote)
				return;
			
			if(guest.isPluginActived(PLUGIN_NAME))
				sendCreateRemoteSync();
			else
				guest.addEventListener(GuestManagerHost.EVENT_GUEST_PLUGIN_ACTIVATED, guestPluginActivatedHandler);
			
			function guestPluginActivatedHandler(event:DesignerEvent):void
			{
				if(PLUGIN_NAME == event.data)
				{
					guest.removeEventListener(GuestManagerHost.EVENT_GUEST_PLUGIN_ACTIVATED, guestPluginActivatedHandler);
					sendCreateRemoteSync();
				}
			}
		}
		
		
		CONFIG::GUEST
		/**
		 *创建一个同步对象 
		 * @param localPath 本地路径
		 * @param remotePath 远程路径
		 * @param syncSubfolder 是否同步子目录
		 * @param channel
		 * @param direction
		 * @param changeLess
		 * @param id
		 * 
		 */
		public function Sync(localPath:String, remotePath:String, syncSubfolder:Boolean,
							 direction:String = DIRECTION_NONE, changeLess:String = CHANGELESS_NONE, id:String = null)
		{
			File.createDirectory("temp");
			File.createDirectory("temp");
			id ||= Math.random().toString();
			_id = id;
			syncMap[id] = this;
			
			if("/" == localPath.charAt(localPath.length - 1) || "\\" == localPath.charAt(localPath.length - 1))
			{
				localPath = localPath.substring(0, localPath.length - 1);
			}
			_localPath = localPath;
			_remotePath = remotePath;
			_syncSubfolder = syncSubfolder;
			_direction = direction;
			_changeLess = changeLess;
			
			log("创建Sync", localPath, remotePath, syncSubfolder, direction, changeLess, id);
			
			scanLocal();
			
			if(isCreatingRemote)
				return;
			sendCreateRemoteSync();
			
			
		}
		
		protected function sendCreateRemoteSync():void
		{
			log("[Sync] 请求创建远程Sync", _id);
			send(CREATE_REMOTE_SYNC, [localPath, remotePath, syncSubfolder, direction, changeLess, _id], remoteSyncCreatedHandler);
		}
		
		protected function remoteSyncCreatedHandler(msg:Message):void
		{
			remoteCrated = true;
			log("远程Sync已经创建", _id);
			work();
		}
		
		
		
		/**
		 *推送本地文件到远程目录
		 * @param path 目录
		 * @param callback 完成时的回调。参数：ok:Boolean 表示是否推送成功
		 * 
		 */
		public function push(path:String, callback:Function):void
		{
			addJob(new SyncJob(JOB_PUSH, callback, path));
		}
		
		protected function pushNow():void
		{
			var job:SyncJob = jobs[0];
			var bytes:ByteArray = readFile(job.path);
			
			if(!bytes)
				return jobDone(false);
			
			log("[Sync] 发送PUSH请求", job.path);
			send(JOB_PUSH, [_id, job.path, bytes], doneMsgHandler);
			
			function doneMsgHandler(msg:Message):void
			{
				//推送成功则将本地文件标记为最新
				if(msg.data)
					lastSyncMap[job.path] = fileMap[job.path];
				
				return jobDone(msg.data);
			}
		}
		
		protected function pushRequestHandler(msg:Message):void
		{
			var path:String = msg.data[1];
			log("[Sync] 收到PUSH请求", path);
			var result:Boolean = writeFile(path, msg.data[2]);
			//写文件成功则更新本地文件时间
			if(result)
				refreshFile(path);
			msg.answer("", result);
		}
		
		protected function refreshFile(path:String):void
		{
			var time:Number;
			CONFIG::HOST
			{
				time = (new File(getFullPath(path))).modificationDate.time
			}
			CONFIG::GUEST
			{
				time = getFileInfo(path).lastWriteTime.time;
			}
			fileMap[path] = time;
			lastSyncMap[path] = time;
		}
		
		/**
		 *从远程目录拉取一个文件 
		 * @param path 目录
		 * @param callback 完成时的回调。参数：ok:Boolean 表示是否拉取成功
		 * 
		 */
		public function pull(path:String, callback:Function):void
		{
			addJob(new SyncJob(JOB_PULL, callback, path));
		}
		
		protected function pullNow():void
		{
			var job:SyncJob = jobs[0];
			send(JOB_PULL, [_id, job.path], doneMsgHandler);
			
			function doneMsgHandler(msg:Message):void
			{
				if(!msg.data)
					return jobDone(false);
				
				var result:Boolean = writeFile(job.path, msg.data);
				//写文件成功则更新本地文件时间
				if(result)
					refreshFile(job.path);
				
				msg.answer("", result);
				
				return jobDone(result);
			}
		}
		
		
		
		protected function pullRequestHandler(msg:Message):void
		{
			var bytes:ByteArray = readFile(msg.data[1]);
			msg.answer("", bytes, bytes ? doneMsgHandler : null);
			
			function doneMsgHandler(msg2:Message):void
			{
				if(msg2.data)
					lastSyncMap[msg.data[1]] = fileMap[msg.data[1]];
					
			}
		}
		
		
		
		/**
		 *扫描远程目录 
		 * @param callback 完成时的回调。参数：fileMap:Object 远程目录的文件表
		 * 
		 */
		public function scanRemote(callback:Function):void
		{
			addJob(new SyncJob(JOB_REMOTE_SCAN, callback, null));
		}
		
		protected function scanRemoteNow():void
		{
			var job:SyncJob = jobs[0];
			send(JOB_REMOTE_SCAN, [_id, job.path], doneMsgHandler);
			
			function doneMsgHandler(msg:Message):void
			{
				if(!msg.data)
				{
					log("[Sync] [Error] 扫描远程目录时发生错误");
				}
				
				return jobDone(msg.data);
			}
		}
		
		protected function scanRemoteRequestHandler(msg:Message):void
		{
			var bytes:ByteArray;
			try
			{
				scanLocal();
				makeChangedMap();
				msg.answer("", [fileMap, lastSyncMap, changedMap]);
			} 
			catch(error:Error) 
			{
				msg.answer("", null);
			}
		}
		
		public function sync(callback:Function):void
		{
			addJob(new SyncJob(JOB_SYNC, callback, null));
		}
		
		protected function syncNow():void
		{
			var job:SyncJob = jobs[0];
			
			if(DIRECTION_NONE == _direction)
			{
				return jobDone(true);
			}
			
			send(JOB_REMOTE_SCAN, [_id, job.path], doneMsgHandler);
			
			if(_changeLess != CHANGELESS_LOCAL)
			{
				scanLocal();
			}
			
			function doneMsgHandler(msg:Message):void
			{
				if(!msg.data)
				{
					log("[Sync] [Error] 同步远程目录时发生错误");
					return jobDone(false);
				}
				
				
				//展开同步工作为一组pull/push工作。最后一个pull/push工作完成时，同步工作完成
				//TODO 扩充本方法以支持更多同步模式
				
				var remoteFileMap:Object = msg.data[0];
				var remoteLastSyncMap:Object = msg.data[1];
				var remoteChangedMap:Object = msg.data[2];
				var subJob:SyncJob;
				var path:String;
				
				switch(_direction)
				{
					case DIRECTION_TO_REMOTE:
						makeChangedMap();
						//传送本地的已改变文件
						for(path in changedMap)
						{
							addJob(new SyncJob(JOB_PUSH, null, path));
						}
						//传送对方缺失的文件
						for(path in fileMap)
						{
							if(!remoteFileMap[path] && !changedMap[path])
								addJob(new SyncJob(JOB_PUSH, null, path));
						}
						break;
					
//					case DIRECTION_TO_LOCAL:
//						for(path in remoteChangedMap)
//						{
//							addJob(new SyncJob(JOB_PULL, null, path));
//						}
//						break;
//					
//					case DIRECTION_TWO_WAY:
//						for(path in lastSyncMap)
//						{
//							subJob = new SyncJob(JOB_PUSH, null, path);
//							addJob(subJob);
//						}
//						
//						for(path in remoteChangedMap)
//						{
//							subJob = new SyncJob(JOB_PULL, null, path);
//							addJob(subJob);
//						}
//
//						break;
					
					default:
						throw new Error("指定的同步方向无法识别");
				}
				
				addJob(new SyncJob(JOB_SYNC_END, job.callback, null))
				job.callback = null;
				jobDone();
			}
		}
		protected function syncEnd():void
		{
			var job:SyncJob = jobs[0];
			jobDone(true);
		}
		
		
		protected function syncPrepareRequestHandler(msg:Message):void
		{
			try
			{
				if(!lastSyncMap || _changeLess != CHANGELESS_REMOTE)
					scanLocal();
				msg.answer("", lastSyncMap);
			} 
			catch(error:Error) 
			{
				msg.answer("", null);
			}
			
		}
		
		protected function work():void
		{
			
			if(working || !remoteCrated || !jobs.length)
				return;
			
			working = true;
			
			
			var job:SyncJob = jobs[0];
			
			log("[Sync] 启动工序", job.type, job.path);
			switch(job.type)
			{
				
				case JOB_SYNC:
					syncNow();
					break;
				
				case JOB_SYNC_END:
					syncEnd();
					break;
				
				case JOB_PULL:
					pullNow();
					break;
				
				case JOB_PUSH:
					pushNow();
					break;
				
				case JOB_REMOTE_SCAN:
					scanRemoteNow();
					break;
				
				default:
					throw new Error("[Sync][Error] 无法识别的工序" + job.type);
			}
		}
		
		
		protected function makeChangedMap():void
		{
			changedMap = {};
			
			for(var path:String in fileMap)
			{
				var current:Number = fileMap[path];
				var lastSync:Number = lastSyncMap[path];
				if(!lastSync)
				{
					changedMap[path] = fileMap[path];
				}
				else if(current != lastSync)
				{
					changedMap[path] = [lastSyncMap[path], fileMap[path]];
				}
			}
			
			for(path in lastSyncMap)
			{
				if(!fileMap[path])
					changedMap[path] = false;
			}
		}
		
		/////////////////////////Native相关代码//////////////////////////
		
		
		protected function readFile(path:String):ByteArray
		{
			path = DataCenter.workSpaceFolderPath + "/" + localPath + "/" + path;
			var bytes:ByteArray;
			
			
			try
			{
				CONFIG::HOST
				{
					var fileStream:FileStream = new FileStream();
					var file:File = new File(path);
					fileStream.open(file, FileMode.READ);
					bytes = new ByteArray;
					fileStream.readBytes(bytes);
				}
				
				CONFIG::GUEST
				{
					bytes = File.readByteArray(path);
				}
			} 
			catch(error:Error) 
			{
				log("[Sync] [Error] 读取本地文件错误，", path);
			}
			
			CONFIG::HOST
			{
				fileStream.close();
			}
			
			return bytes;
		}
		
		protected function writeFile(path:String, bytes:ByteArray):Boolean
		{
			path = getFullPath(path);
			
			try
			{
				CONFIG::HOST
				{
					var fileStream:FileStream = new FileStream();
					fileStream.open(new File(path), FileMode.WRITE);
					fileStream.writeBytes(bytes);
					fileStream.close();
				}
				CONFIG::GUEST
				{
					//如果文件表中没有，则认为文件可能不存在->包含文件的目录可能不存在->尝试创建目录
					if(!fileMap[path])
					{
						var temp:Array = path.split("/");
						var fileName:String = temp.pop();
						var parentPath:String = temp.join("/");
						File.createDirectory(parentPath);
					}
					
					File.writeByteArray(path, bytes);
				}
			} 
			catch(error:Error) 
			{
				log("[Sync] [Error] 写文件时发生错误", path);
				CONFIG::HOST
				{
					fileStream.close();
				}
				
				return false;
			}
			
			return true;
		}
		
		CONFIG::HOST
		public function scanLocal():void
		{
			var rootFile:File = new File(DataCenter.workSpaceFolderPath + "/" + localPath);
			scanThis(rootFile);
			//TODO
			
			function scanThis(file:File):void
			{
				if(!file.exists)
				{
					return;
				}
				
				if(file.isDirectory)
				{
					for each(var i:File in file.getDirectoryListing())
					{
						if(!i.isDirectory || syncSubfolder)
							scanThis(i);
					} 
				}
				else
				{
					var path:String = rootFile.getRelativePath(file);
					log("[Sync] 扫描了文件", path);
					fileMap[path] = file.modificationDate.time;
				}
			}
		}
		
		CONFIG::GUEST
		/**
		 *扫描本地目录，这是一个同步操作。
		 */
		public function scanLocal():void
		{
			fileMap = {};
			var fileInfo:FileInfo = getFileInfo("");
			
			if(!fileInfo)
			{
				log("[Sync] [Alerm] 指定要同步的根文件/目录不存在");
				return;
			}
			
			if(fileInfo.isDirectory)
			{
				scanFold("");
			}
			else
			{
				fileMap[""] = fileInfo.lastWriteTime.time;
			}
			
			
			function scanFold(foldPath:String):void
			{
				for each(var i:FileInfo in File.getDirectoryListing(getFullPath(foldPath)))
				{
					if("." == i.name || ".." == i.name)
					{
						continue;
					}
					
					var currentPath:String = foldPath ? foldPath + "/" + i.name : i.name;//不会出现"/file.txt"
					
					if(i.isDirectory)
					{
						if(syncSubfolder)
							scanFold(currentPath);
					}
					else
						
					{
						log("[Sync] 扫描了文件 \"" + currentPath + "\"");
						fileMap[currentPath] = i.lastWriteTime.time;
					}
				}
			}
		}
		
		
		CONFIG::GUEST
		protected function getFileInfo(path:String):FileInfo
		{
			var temp:Array = getFullPath(path).split("/");
			var fileName:String = temp.pop();
			var parentPath:String = temp.join("/");
			
			try
			{
				var list:Array = File.getDirectoryListing(parentPath);
			} 
			catch(error:Error) 
			{
				return null;
			}
			
			
			for each(var i:FileInfo in list)
			{
				if(i.name == fileName)
				{
					return i;
				}
			}
			
			return null;
		}
		
//		/**
//		 *更新单个文件信息
//		 */
//		CONFIG::GUEST
//		protected function updateFileInfo(path:String):void
//		{
//			
//			fileMap[path] = getFileInfo(path).lastWriteTime.time;
//		}
//		
//		CONFIG::HOST
//		protected function updateFileInfo(path:String):void
//		{
//			var file:File = new File(path);
//			
//			fileMap[path] = file.modificationDate.time;
//		}
		
//		protected function getRelativePath(fullPath:String):String
//		{
//			return null;
//		}
		
		protected function getFullPath(relativePath:String):String
		{
			var ret:String = DataCenter.workSpaceFolderPath + "/" + localPath + "/" + relativePath;
			if("/" == ret.charAt(ret.length - 1) || "\\" == ret.charAt(ret.length - 1))
			{
				ret = ret.substring(0, ret.length - 1);
			}
			return ret;
		}
		
		protected function getParentPath(fullPath:String):String
		{
			var temp:Array = fullPath.split("/");
			var fileName:String = temp.pop();
			return temp.join("/");
		}
		
		////////////////////////读写器/////////////////////////////////////
		
		

		/**
		 *同步的本地路径 
		 */
		public function get localPath():String
		{
			return _localPath;
		}

		/**
		 * 同步的远程路径
		 */
		public function get remotePath():String
		{
			return _remotePath;
		}

		/**
		 *同步模式 
		 */
		public function get direction():String
		{
			return _direction;
		}

		
		/**
		 * 非易变目录设定
		 * <br>您可指定本地文件夹或者远程文件夹为非易变。非易变目录在同步之前不会被扫描。
		 * <br>如果您正在从主机端向客户端同步一个很大的资源文件夹，则将客户端目录设置为非易变将有效地提升同步速度。
		 * <br>当使用双向同步时，将任一目录指定为非易变可能会让同步操作不能正常完成。
		 */		
		public function get changeLess():String
		{
			return _changeLess;
		}

		public function set changeLess(value:String):void
		{
			_changeLess = value;
		}

		public function get syncSubfolder():Boolean
		{
			return _syncSubfolder;
		}


	}
}