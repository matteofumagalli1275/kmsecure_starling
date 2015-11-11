package 
{
	import starling.display.Button;
	import starling.display.ButtonState;
	import starling.display.Image;
    import starling.display.Quad;
    import starling.display.Sprite;
	import starling.events.Event;
	import starling.textures.Texture;
	import starling.utils.AssetManager;
    import starling.utils.Color;
	import starling.animation.Transitions;
	import starling.core.Starling;
	import flash.filesystem.File;
 
    public class Game extends Sprite
    {
		private var assets:AssetManager;
		private var background:Image;
		
        public function Game()
        {
			KMSecure.add_key("MY_KEY");
			assets = new KMSecureAssetManager();
			assets.verbose = true;
			var appDir:File = File.applicationDirectory;
			assets.enqueue(appDir.resolvePath("output_soft_crypt"));
			//assets.enqueue(appDir.resolvePath("output_hard_crypt"));
			//assets.enqueue(appDir.resolvePath("output_original"));
			assets.loadQueue(function(ratio:Number):void
			{
				if (ratio == 1.0)
					Init();
			});
        }
		
		public function Init():void
		{
			
			background = new Image(assets.getTexture("background.png"));
			if (background != null)
				trace("background loaded");
			
			InitScene();
		}
		
		public function InitScene():void
		{
			addChild(background);
		}
		
    }

}