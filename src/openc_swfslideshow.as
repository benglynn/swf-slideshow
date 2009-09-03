package {
	
	/**
	 * In this application 'movie' refers to the SWF loaded in, 'slide' refers to the animation
	 * 
	 * These two *may* be the same thing, but a movie may otherwsie be just one 
	 * frame long, and contain a masked movie. In which case the latter will be 
	 * treated as the slide.
	 * 
	 * The 'movie' is loaded, stacked, hidden, shown, and faded.
	 * The 'slide' is stopped, rewound and played.
	 */
	 
	import flash.display.*;
	import flash.events.*;
	import flash.geom.ColorTransform;
	import flash.net.*;
	import flash.utils.*;
	import mx.effects.easing.*;

	[SWF (frameRate="21", backgroundColor="0xffffff", pageTitle="openc.swfslideshow")]
	
	/**
	 * This movie parses a config file and plays through a series of swf movies
	 * (called slides)` with configurable alpha and brightness transitions 
	 * between each one.
	 */
	public class openc_swfslideshow extends Sprite {
		
		/**
		 * The number of slides
		 */
		protected var numSlides:uint;
		
		/**
		 * The directory from which to load config.xml
		 */
		protected var RESOURCES_DIRECTORY:String = "../resources/opensite";
		
		/**
		 * A store for configuration after parsing conifg.xml
		 */
		protected var config:Object = new Object;
		
		/**
		 * Constructor. Sets stage scale mode. Sets default configuration 
		 * values. Looks for a query-string parameter 'resourcesDirectory', if 
		 * present, overrides RESOURCES_DIRECTORY. Loads config.xml and sets 
		 * handler
		 * 
		 * @see #initialiseConfig()
		 * @see #handleXMLLoadComplete()
		 */
		public function openc_swfslideshow() {
			
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			
			// Set default configuration values
			initialiseConfig();
			
			// Allow the resource directory to be overriden by a q/s param
			if(loaderInfo.parameters.hasOwnProperty('resourcesDirectory')) {
				RESOURCES_DIRECTORY = loaderInfo.parameters['resourcesDirectory'];
			}
			
			// Load config and set handler
			var loader:URLLoader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			loader.addEventListener(Event.COMPLETE, handleXMLLoadComplete);
			loader.load(new URLRequest(this.RESOURCES_DIRECTORY + '/config.xml'));
		}
		
		/**
		 * Sets default configuration options. Strangely, this needs to be in a
		 *  different frame to that which loads the XML
		 */
		 protected function initialiseConfig():void {
			config.alpha_fade_in = 0;
		 	config.alpha_fade_out = 0;
			config.brightness_fade_in = 0;
			config.brightness_fade_out = 0;
			config.brightness_offset = 0;
			config.order = "source";
			config.overlap = 0;
		 }

		/**
		 * Config has loaded. Override any specified configuration. Load slides
		 * and set handlers.
		 * 
		 * @param event Event.COMPLETE fired when config.xml loads
		 */
		protected function handleXMLLoadComplete(event:Event):void {

			try {
				var XMLConfig:XML = new XML(event.target.data);
				
				// Look for XML equivalents of config properties in the root node of the XML
				for(var configName:String in config) {					
					
					var XMLName:String = configName.replace(/_/g, '-');
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
				
				// Load each slide defined in config
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
			catch(e:Error) {
				trace(e.message);
			}
		}
		
		/**
		 * A slide's movie has loaded. Examine to determine if this is a masked
		 * movie, and if so, target the mask movie for all measurements, 
		 * stopping and rewinding etc. 
		 */
		protected function handleMovieComplete(e:Event, sourceIndex:uint, href:String):void {
			
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
			movie._slide_.visible = false;
			
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
			
			// If all the slides have loaded, stack in order and play
			if(numChildren == numSlides) {
				stackMovies();
				playSlideAt(numChildren-1);
			}
		}
		
		/**
		 * Movie was clicked
		 */
		protected function movieClickHandler(movie:MovieClip):void {

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
		protected function stackMovies():void {	
			
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
				trace("Stacking", i);
				movie.left = movie.top = i * 10;
			}
		}
		
		/**
		 * Start a slide playing and attach enterFrame handler.
		 * 
		 * @see #handleSlideEnterFrame()
		 */
		protected function playSlideAt(index:uint):void {
			var movie:MovieClip = getChildAt(index) as MovieClip;
			movie._slide_.addEventListener(Event.ENTER_FRAME, handleSlideEnterFrame);
			movie._slide_.play(); 
		}
		
		/**
		 * Slide enter frame handler. Rewind if this slide has not fully loaded.
		 * Fade alpha or brightness if config says it should be fading. Play the
		 * next slide down in the stack when either this slide has finished, or
		 * the next is configured to play with an overlap. Remove handler when
		 * stopped.
		 */
		protected function handleSlideEnterFrame(e:Event):void {
			var slide:MovieClip = e.target as MovieClip;
			
			// If this slide has not fully loaded
			if(slide.framesLoaded != slide.totalFrames) {
				slide.gotoAndPlay(1);
				return;
			}
			
			var colour:ColorTransform = new ColorTransform;

			 // Alpha fading; fade out takes precedence over fade in if there's 
			 // an overlap
			var elapsedAlphaTime:uint;
			var initialAlpha:Number = 0;
			var alphaChange:Number = 0;
						
			// If into fade out time
			if(slide.currentFrame > slide.totalFrames - config.alpha_fade_out) {
				elapsedAlphaTime = config.alpha_fade_out - (slide.totalFrames - slide.currentFrame);
				alphaChange = -255;
				colour.alphaOffset = Exponential.easeIn(elapsedAlphaTime, initialAlpha, alphaChange, config.alpha_fade_out);
			} 
			
			// Else if into fade in time
			else if (slide.currentFrame < config.alpha_fade_in) {
				elapsedAlphaTime = slide.currentFrame;
				initialAlpha = -255;
				alphaChange = 255;
				colour.alphaOffset = Exponential.easeOut(elapsedAlphaTime, initialAlpha, alphaChange, config.alpha_fade_in);
			}

			 // Brightness fading; fade out takes precedence over fade in if 
			 // there's an overlap
			var elapsedBrightnessTime:uint;
			var initialBrightness:Number = 0;
			var brightnessChange:Number = 0;
						
			// If into brightness fade out time
			if(slide.currentFrame > slide.totalFrames - config.brightness_fade_out) {
				elapsedBrightnessTime = config.brightness_fade_out - (slide.totalFrames - slide.currentFrame);
				brightnessChange = config.brightness_offset;
				colour.redOffset = colour.greenOffset = colour.blueOffset = Exponential.easeIn(elapsedBrightnessTime, initialBrightness, brightnessChange, config.brightness_fade_out);
			} 
			
			// Else if into brightness fade in time
			else if (slide.currentFrame < config.brightness_fade_in) {
				elapsedBrightnessTime = slide.currentFrame;
				initialBrightness = config.brightness_offset;
				brightnessChange = -config.brightness_offset;
				colour.redOffset = colour.greenOffset = colour.blueOffset = Exponential.easeOut(elapsedBrightnessTime, initialBrightness, brightnessChange, config.brightness_fade_in);
			}
			
			// Apply the colour transformation
			slide.transform.colorTransform = colour;
			slide.visible = true;
			
			// If this is the last frame
			if(slide.currentFrame == slide.totalFrames) {
				slide.removeEventListener(Event.ENTER_FRAME, handleSlideEnterFrame);
				slide.gotoAndStop(1);
				setChildIndex(slide._movie_, 0);
				// If there is no overlap, now's the time to play the next slide
				if(config.overlap == 0) {
					playSlideAt(numChildren-1);
				}
			}
			
			// If there is an overlap, and that many frames remain
			if(slide.currentFrame == slide.totalFrames - config.overlap) {
				playSlideAt(numChildren-2);
			}
		}
	}
	
}
