package {
	
	import flash.display.*;
	import flash.events.*;
	import flash.net.*;
	import flash.utils.*;

	[SWF (width="800", height="500", frameRate="21", backgroundColor="0x000000", pageTitle="openc.swfslideshow")]
	
	public class openc_swfslideshow extends Sprite {
		
		private var numSlides:uint;
		
		private var resourcesDirectory:String = "../resources/";
		
		// Main constuctor
		public function openc_swfslideshow() {
			
			var loader:URLLoader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			loader.addEventListener(Event.COMPLETE, handleXMLLoadComplete);
			loader.load(new URLRequest(this.resourcesDirectory + 'config.xml'));
		}

		private function handleXMLLoadComplete(event:Event):void {

			try {
				var config:XML = new XML(event.target.data);
				numSlides = config.slide.length();
				var count:uint = 0;
				for each(var slide:XML in config.slide) {
					var src:String = this.resourcesDirectory + slide.@src;
					var loader:Loader = new Loader();
					loader.contentLoaderInfo.addEventListener(
						Event.COMPLETE,
						function(sourceIndex:uint, src:String):Function {
							return function(e:Event):void {
								handleSlideComplete(e, sourceIndex, src);
							}
						}(count++, src)
					);
					loader.load(new URLRequest(src));
				}
			}
			catch(e:TypeError) {
				trace(e.message);
			}
		}
		
		private function handleSlideComplete(e:Event, sourceIndex:uint, src:String):void {
			var movie:MovieClip = e.target.content as MovieClip;
			movie.gotoAndStop(1);
			movie.visible = false;
			movie._sourceIndex_ = sourceIndex;
			movie._src_ = src;
			//movie.visible = false;
			this.addChild(movie);
			
			// If all the slides have loaded, stack in order
			if(numChildren == numSlides) {
				// Create a children array s will itterate while mixing up stack
				var children:Array = new Array(numChildren);
				for(var i:uint = 0 ; i < numChildren ; i++) {
					children[i] = this.getChildAt(i);
				}
				// Stack as determined by XML source order
				for(var j:uint = 0 ; j < numChildren ; j++) {
					var slide:MovieClip = children[j] as MovieClip;
					slide.x = slide.y = 20 * slide._sourceIndex_;
					this.setChildIndex(slide, numChildren - slide._sourceIndex_ - 1);
				}
				trace("*");
				playTopSlide();
			}
		}
		
		private function playTopSlide():void {
			var movie:MovieClip = getChildAt(numChildren-1) as MovieClip;
			movie.addEventListener(Event.ENTER_FRAME, handleBannerEnterFrame)
			movie.visible = true;
			movie.play(); 
		}
		
		private function handleBannerEnterFrame(e:Event):void {
			var movie:MovieClip = e.target as MovieClip;
			if(movie.currentFrame == movie.totalFrames) {
				movie.removeEventListener(Event.ENTER_FRAME, handleBannerEnterFrame);
				movie.gotoAndStop(1);
				setChildIndex(movie, 0)
				playTopSlide();
			}
		}
	}
	
}
