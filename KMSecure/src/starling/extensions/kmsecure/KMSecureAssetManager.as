package 
{
	import flash.display.Bitmap;
    import flash.display.Loader;
    import flash.display.LoaderInfo;
    import flash.events.HTTPStatusEvent;
    import flash.events.IOErrorEvent;
    import flash.events.ProgressEvent;
    import flash.events.SecurityErrorEvent;
    import flash.media.Sound;
    import flash.media.SoundChannel;
    import flash.media.SoundTransform;
    import flash.net.FileReference;
    import flash.net.URLLoader;
    import flash.net.URLLoaderDataFormat;
    import flash.net.URLRequest;
    import flash.system.ImageDecodingPolicy;
    import flash.system.LoaderContext;
    import flash.system.System;
    import flash.utils.ByteArray;
    import flash.utils.Dictionary;
    import flash.utils.describeType;
    import flash.utils.getQualifiedClassName;
    import flash.utils.setTimeout;
	
	import starling.utils.SystemUtil;
	import starling.utils.AssetManager;
	import starling.core.Starling;
    import starling.events.Event;
    import starling.events.EventDispatcher;
    import starling.text.BitmapFont;
    import starling.text.TextField;
    import starling.textures.AtfData;
    import starling.textures.Texture;
    import starling.textures.TextureAtlas;
    import starling.textures.TextureOptions;
	/**
	 * ...
	 * @author 
	 */
	public class KMSecureAssetManager extends AssetManager
	{
		private static const HTTP_RESPONSE_STATUS:String = "httpResponseStatus";
		
		private var mCheckPolicyFile:Boolean;
		
		public function KMSecureAssetManager(scaleFactor:Number=1, useMipmaps:Boolean=false)
		{
			super(scaleFactor,useMipmaps);
		}
		
		 /** This method is called internally for each element of the queue when it is loaded.
         *  'rawAsset' is typically either a class (pointing to an embedded asset) or a string
         *  (containing the path to a file). For texture data, it will also be called after a
         *  context loss.
         *
         *  <p>The method has to transform this object into one of the types that the AssetManager
         *  can work with, e.g. a Bitmap, a Sound, XML data, or a ByteArray. This object needs to
         *  be passed to the 'onComplete' callback.</p>
         *
         *  <p>The calling method will then process this data accordingly (e.g. a Bitmap will be
         *  transformed into a texture). Unknown types will be available via 'getObject()'.</p>
         *
         *  <p>When overriding this method, you can call 'onProgress' with a number between 0 and 1
         *  to update the total queue loading progress.</p>
         */
        override protected function loadRawAsset(rawAsset:Object, onProgress:Function, onComplete:Function):void
        {
            var extension:String = null;
            var loaderInfo:LoaderInfo = null;
            var urlLoader:URLLoader = null;
            var urlRequest:URLRequest = null;
            var url:String = null;

            if (rawAsset is Class)
            {
                setTimeout(complete, 1, new rawAsset());
            }
            else if (rawAsset is String || rawAsset is URLRequest)
            {
                urlRequest = rawAsset as URLRequest || new URLRequest(rawAsset as String);
                url = urlRequest.url;
                extension = getExtensionFromUrl(url);

                urlLoader = new URLLoader();
                urlLoader.dataFormat = URLLoaderDataFormat.BINARY;
                urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
                urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
                urlLoader.addEventListener(HTTP_RESPONSE_STATUS, onHttpResponseStatus);
                urlLoader.addEventListener(ProgressEvent.PROGRESS, onLoadProgress);
                urlLoader.addEventListener(Event.COMPLETE, onUrlLoaderComplete);
                urlLoader.load(urlRequest);
            }

            function onIoError(event:IOErrorEvent):void
            {
                log("IO error: " + event.text);
                dispatchEventWith(Event.IO_ERROR, false, url);
                complete(null);
            }

            function onSecurityError(event:SecurityErrorEvent):void
            {
                log("security error: " + event.text);
                dispatchEventWith(Event.SECURITY_ERROR, false, url);
                complete(null);
            }

            function onHttpResponseStatus(event:HTTPStatusEvent):void
            {
                if (extension == null)
                {
                    var headers:Array = event["responseHeaders"];
                    var contentType:String = getHttpHeader(headers, "Content-Type");

                    if (contentType && /(audio|image)\//.exec(contentType))
                        extension = contentType.split("/").pop();
                }
            }

            function onLoadProgress(event:ProgressEvent):void
            {
                if (onProgress != null && event.bytesTotal > 0)
                    onProgress(event.bytesLoaded / event.bytesTotal);
            }
            
            function onUrlLoaderComplete(event:Object):void
            {
                var bytes:ByteArray = transformData(urlLoader.data as ByteArray, url);
                var sound:Sound;

				bytes = KMSecure.decrypt(bytes);


                if (bytes == null)
                {
                    complete(null);
                    return;
                }
                
                if (extension)
                    extension = extension.toLowerCase();

                switch (extension)
                {
                    case "mpeg":
                    case "mp3":
                        sound = new Sound();
                        sound.loadCompressedDataFromByteArray(bytes, bytes.length);
                        bytes.clear();
                        complete(sound);
                        break;
                    case "jpg":
                    case "jpeg":
                    case "png":
                    case "gif":
                        var loaderContext:LoaderContext = new LoaderContext(mCheckPolicyFile);
                        var loader:Loader = new Loader();
                        loaderContext.imageDecodingPolicy = ImageDecodingPolicy.ON_LOAD;
                        loaderInfo = loader.contentLoaderInfo;
                        loaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
                        loaderInfo.addEventListener(Event.COMPLETE, onLoaderComplete);
                        loader.loadBytes(bytes, loaderContext);
                        break;
                    default: // any XML / JSON / binary data 
                        complete(bytes);
                        break;
                }
            }
            
            function onLoaderComplete(event:Object):void
            {
                urlLoader.data.clear();
                complete(event.target.content);
            }
            
            function complete(asset:Object):void
            {
                // clean up event listeners

                if (urlLoader)
                {
                    urlLoader.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
                    urlLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
                    urlLoader.removeEventListener(HTTP_RESPONSE_STATUS, onHttpResponseStatus);
                    urlLoader.removeEventListener(ProgressEvent.PROGRESS, onLoadProgress);
                    urlLoader.removeEventListener(Event.COMPLETE, onUrlLoaderComplete);
                }

                if (loaderInfo)
                {
                    loaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
                    loaderInfo.removeEventListener(Event.COMPLETE, onLoaderComplete);
                }

                // On mobile, it is not allowed / endorsed to make stage3D calls while the app
                // is in the background. Thus, we pause queue processing if that's the case.
                
                if (SystemUtil.isDesktop)
                    onComplete(asset);
                else
                    SystemUtil.executeWhenApplicationIsActive(onComplete, asset);
            }
        }
		
		private function getHttpHeader(headers:Array, headerName:String):String
		{
			if (headers)
			{
				for each (var header:Object in headers)
					if (header.name == headerName) return header.value;
			}
			return null;
		}
		
	}
	

}