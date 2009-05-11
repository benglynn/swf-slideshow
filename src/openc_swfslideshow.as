package {
	
	/**
	 * In this application 'movie' refers to the SWF loaded in, 'slide' refers to
	 * the animation, which should be at least twice as long as CROSSFADE_DURATION.
	 * 
	 * These two *may* be the same thing, but a movie may otherwsie be just one 
	 * frame long, and contain a masked movie. In which case the latter will be 
	 * treated as the slide.
	 * 
	 * The 'movie' is loaded, stacked, hidden, shown, and cross faded.
	 * The 'slide' is stopped, rewound and played.
	 */
	 
	import flash.display.*;
	import flash.events.*;
	import flash.geom.ColorTransform;
	import flash.net.*;
	import flash.utils.*;
	
	import mx.effects.easing.*;

	[SWF (frameRate="21", backgroundColor="0x000000", pageTitle="openc.swfslideshow")]
	
	public class openc_swfslideshow extends Sprite {
		
		private var numSlides:uint;
		 
		private var BURN:Boolean = true;
		private var RESOURCES_DIRECTORY:String = "resources";
		
		private var config:Object = new Object;;
		
		/**
		 * Constructor
		 */
		public function openc_swfslideshow() {
			
			// Set default configuration values
			config.fade_out = 0;
			config.burn_out = 0;
			config.order = "source";
			
			// Allow the resource directory to be overriden by a q/s param
			if(loaderInfo.parameters.hasOwnProperty('resourcesDirectory')) {
				RESOURCES_DIRECTORY = loaderInfo.parameters['resourcesDirectory'];
			}
			
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			
			var loader:URLLoader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			loader.addEventListener(Event.COMPLETE, handleXMLLoadComplete);
			loader.load(new URLRequest(this.RESOURCES_DIRECTORY + '/config.xml'));
		}

		/**
		 * Configuration has loaded
		 */
		private function handleXMLLoadComplete(event:Event):void {

			try {
				var XMLConfig:XML = new XML(event.target.data);
				
				// Look for XML equivalents of config properties in the root node of the XML
				for(var configName:String in config) {
					var XMLName:String = configName.replace('_', '-');
					var XMLValue:String = XMLConfig.attribute(XMLName)[0];
					if(XMLValue) {
						switch(typeof config[configName]){
							case "number":
								config[configName] = parseInt(XMLValue);
								break;
							case "string":
								config[configName] = XMLValue;
								break
						}
					}
				}
				
				// Look for burn configuration
				var burn:String = XMLConfig.@burn[0];
				if(burn == "yes") {
					BURN = true;
				}
				
				numSlides = XMLConfig.movie.length();
				var count:uint = 0;
				for each(var movie:XML in XMLConfig.movie) {				
					
					var loader:Loader = new Loader();
					loader.contentLoaderInfo.addEventListener(
						Event.COMPLETE,
						function(sourceIndex:uint, href:String):Function {
							return function(e:Event):void {
								handleMovieComplete(e, sourceIndex, href);
							}
						}(count++, movie.@href[0])
					);
					
					var src:String = this.RESOURCES_DIRECTORY + "/" + movie.@src;
					loader.load(new URLRequest(src));
				}
			}
			catch(e:TypeError) {
				trace(e.message);
			}
		}
		
		/**
		 * Movie has loaded
		 */
		private function handleMovieComplete(e:Event, sourceIndex:uint, href:String):void {
			
			var movie:MovieClip = e.target.content as MovieClip;

			// Assume the slide is the entire movie
			movie._slide_ = movie;
			
			// If the movie has one frame and no more than two children,
			// assume it contains a (posibly masked) slide movie
			if(movie.totalFrames == 1 && movie.numChildren <= 2) {
				movie._slide_ = movie.getChildAt(movie.numChildren-1);
			}
			
			// Add a reference back from the slide to the movie
			movie._slide_._movie_ = movie;
			
			// Rewind and hide
			movie._slide_.gotoAndStop(1);
			movie.visible = false;
			
			// Save reference to the order that this movie had in the XML
			movie._sourceIndex_ = sourceIndex;
			
			// If a @href existed in the XML element
			if(href) {
				movie._href_ = href;
				movie.addEventListener(MouseEvent.CLICK, function(movie:MovieClip):Function {
					return function():void {
						movieClickHandler(movie);
					}
				}(movie));
				movie.buttonMode = true;
			}
			
			this.addChild(movie);
			
			// If all the slides have loaded, stack in order
			if(numChildren == numSlides) {
				stackMovies();
				
				// Show all
				for(var i:uint = 0 ; i < numChildren ; i++) {
					getChildAt(i).visible = true;
				}
				// Kick off
				playTopSlide();
			}
		}
		
		/**
		 * Movie was clicked
		 */
		private function movieClickHandler(movie:MovieClip):void {

			try {
				navigateToURL( new URLRequest(movie._href_), "_self" );
			}
			catch(e:Error) {
				trace(e.message);
			}

		}
		
		/**
		 * Stack the movies in the order which they will play, first on top
		 */
		private function stackMovies():void {	
			
			// Create an array representing child movies
			var children:Array = new Array(numChildren);
			for(var i:uint = 0 ; i < numChildren ; i++) {
				children[i] = this.getChildAt(i);
			}
			switch(config.order) {
				
			 case "random":
				children.sort(function():Number {
					return Math.random() > 0.5 ? 1 : -1;
				});
				break;
			
			case "source":
				children.sort(function(a:MovieClip, b:MovieClip):Number {
					return a._sourceIndex_ > b._sourceIndex_  ? -1 : 1;
				});
				break;
			}
			
			// Stack each child according to its sorted index
			for(i = 0 ; i < numChildren ; i++) {
				var movie:MovieClip = children[i] as MovieClip;
				setChildIndex(movie, i);
			}
		}
		
		/**
		 * Play top slide in stack
		 */
		private function playTopSlide():void {
			var movie:MovieClip = getChildAt(numChildren-1) as MovieClip;
			movie._slide_.addEventListener(Event.ENTER_FRAME, handleSlideEnterFrame);
			movie._slide_.play(); 
		}
		
		/**
		 * Slide enter frame
		 */
		private function handleSlideEnterFrame(e:Event):void {
			var slide:MovieClip = e.target as MovieClip;
			
			// Fade out if into crossfade time
			if(slide.currentFrame > slide.totalFrames - config.fade_out) {
				var time:Number = config.fade_out - (slide.totalFrames - slide.currentFrame);
				var initialValue:Number = 1;
				var totalChange:Number = -1;
				slide.alpha = Exponential.easeIn(time, initialValue, totalChange, config.fade_out);
			}
			
			if(slide.currentFrame > slide.totalFrames - config.burn_out) {
				time = config.burn_out - (slide.totalFrames - slide.currentFrame);
				var initialBrightness:Number = 0;
				var finalBrightness:Number = 255;
				var colour:ColorTransform = new ColorTransform;
				colour.redOffset = colour.greenOffset = colour.blueOffset = Exponential.easeIn(time, initialBrightness, finalBrightness, config.burn_out);
				slide.transform.colorTransform = colour;
			}
			
			// If this is the last frame
			if(slide.currentFrame == slide.totalFrames) {
				slide.removeEventListener(Event.ENTER_FRAME, handleSlideEnterFrame);
				slide.gotoAndStop(1);
				setChildIndex(slide._movie_, 0);
				slide.alpha = 1;
				var colourReset:ColorTransform = new ColorTransform;
				colourReset.redOffset = colourReset.greenOffset = colourReset.blueOffset = 0;
				slide.transform.colorTransform = colourReset; 
				playTopSlide();
			}
		}
	}
	
}
