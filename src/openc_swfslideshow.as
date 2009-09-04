package {
	
	
	 
	import flash.display.*;
	import flash.events.*;
	import flash.geom.ColorTransform;
	import flash.net.*;
	import flash.utils.*;
	
	import mx.core.MovieClipLoaderAsset;
	import mx.effects.easing.*;

	/**
	 * Resulting swf has a frame rate of 21, this will override framerates of
	 * individual slides. Width and height also set to match example swfs though 
	 * these will be overriden when movie embedded in web page
	 */
	[SWF (frameRate="21", backgroundColor="0xffffff", pageTitle="openc.swfslideshow")]
	
	/**
	 * This movie parses a config file and plays through a series of swf movies
	 * with configurable alpha and brightness transitions between each one.
	 */
	public class openc_swfslideshow extends Sprite {
		
		/**
		 * Initial delay before loading first movie
		 */
		 private const INITIAL_DELAY:uint = 300;
		
		/**
		 * Loading animation raw emed
		 */
		 [Embed(source="../swf/loading.swf")]
		 protected var loadingAnimationRaw:Class;
		 
		 /**
		 * Loading nimation
		 */
		 protected var loadingAnimation:MovieClipLoaderAsset;		 
		 
		 /**
		 * Movies container
		 */
		 protected var movies:DisplayObjectContainer;
		 
		 /**
		 * Movies array, hold movie XML elements from config in play order
		 */
		 protected var movieConfigs:Array = new Array();
		
		/**
		 * The directory from which to load config.xml
		 */
		protected var RESOURCES_DIRECTORY:String = "../resources/wren";
		
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
			
			// Container for slides
			movies = new MovieClip();
			addChild(movies);
			
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
		 	config.width = 60;
		 	config.height = 60;
			config.alpha_fade_in = 0;
		 	config.alpha_fade_out = 0;
			config.brightness_fade_in = 0;
			config.brightness_fade_out = 0;
			config.brightness_offset = 0;
			config.order = "source";
			config.overlap = 0;
		 }

		/**
		 * Config has loaded. Override any specified configuration. Load movies
		 * and set handlers.
		 * 
		 * @param event Event.COMPLETE fired when config.xml has loaded
		 */
		protected function handleXMLLoadComplete(event:Event):void {

			var XMLConfig:XML = new XML(event.target.data);
			
			// Look for XML equivalents of config properties in the root 
			// node of the XML
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
			
			
			// Position and display loading animation
			loadingAnimation = new loadingAnimationRaw();
			this.loadingAnimation.x = config.width/2 - this.loadingAnimation.width/2
			this.loadingAnimation.y = config.height/2 - this.loadingAnimation.height/2
			addChild(loadingAnimation);
			
			// Loop through config movies, add each to an array to reorder
			var count:uint = 0;
			for each(var movie:XML in XMLConfig.movie) {
				movieConfigs.push(movie);
			}
			
			// Juggle order if config order set to random
			if(config.order == "random") {
				movieConfigs.sort(function():Number {
					return Math.random() > 0.5 ? 1 : -1;
				});
			}
			
			// Store reference to play order, so this can be established quickly
			// when this element is detached from this array
			for(var i:uint = 0 ; i < movieConfigs.length ; i++) {
				movieConfigs[i].@playIndex = i;
			}
			
			// Load the first movie, from here on, movies loaded by other movies
			loadMovie(movieConfigs[0], true);
		}
		
		/**
		 * Load movie
		 * 
		 * @parm movie the XML element from config representing the movie
		 */
		 protected function loadMovie(movie:XML, isFirstMovie:Boolean=false):void {
		 	var resourceDirectory:String = this.RESOURCES_DIRECTORY;
		 	var closure:Function = function():void {
				var loader:Loader = new Loader();
				loader.contentLoaderInfo.addEventListener(
					Event.COMPLETE, 
					function(e:Event):void {
						movieLoaded(e, movie);
					}
				);
				var src:String = resourceDirectory + "/" + movie.@src;
				loader.load(new URLRequest(src));
		 	}
		 	// Delay defaults to zero if not defined on element
		 	var delay:uint = parseInt(movie.@delay);
		 	// Make sure that there's a minimum delay for the first movie to 
		 	// avoid first load getting last and also loading animation flicker
		 	if(isFirstMovie) {
		 		delay = Math.max(delay, INITIAL_DELAY);
		 	}
		 	setTimeout(closure, delay);
		 }
		 
		 /**
		 * A movie has loaded, add it at the bottom of the movies stack. If it's 
		 * the first, play it. If is a next, load it.
		 */
		 protected function movieLoaded(event:Event, movieConfig:XML):void {
			
			var movie:MovieClip = event.target.content as MovieClip;
			
		 	// Save any values from movie config into the movie
			movie._playIndex_ = parseInt(movieConfig.@playIndex);
			movie._src_ = movieConfig.@src;
			movie._href_ = movieConfig.@href;
			
			// Add other metadata
			movie._isPlaying_ = false;
			
			// If necessary, add click handler
			if(movie._href_) {
				movie.addEventListener(MouseEvent.CLICK, function(movie:MovieClip):Function {
					return function():void {
						movieClickHandler(movie);
					}
				}(movie));
				movie.buttonMode = true;
			}

			// Assume the slide is the entire movie
			movie._slide_ = movie;
			
			// If the movie has one frame and no more than two children,
			// assume it contains a (posibly masked) slide movie
			if(movie.totalFrames == 1 && movie.numChildren <= 2) {
				movie._slide_ = movie.getChildAt(movie.numChildren-1);
			}
			
			// Add a reference back from the slide to the movie
			movie._slide_._movie_ = movie;
			
			// Rewind
			movie._slide_.gotoAndStop(1);
			
			// Hide incase movie starts with a fade in
			movie._slide_.visible = false;
			
			// Add movie to movies collection
			movies.addChildAt(movie, 0);
			
			// DEBUG: show stacking order
			//movie.x = movie.y = movieConfig.@playIndex * 30;
			
			// Start this movie playing if it's the first
			if(movie._playIndex_ == 0) {
				playSlideInMovie(movie);
			}
			
			// Load the next movie to play, if there is one
			var nextMovie:uint = movie._playIndex_ + 1;
			if(movieConfigs.length > nextMovie) {
				loadMovie(movieConfigs[nextMovie]);
			}
		 	
		 }

		
		/**
		 * Start a slide playing and attach enterFrame handler.
		 * 
		 * @param index the index of the movie within movies stack
		 * 
		 * @see #handleSlideEnterFrame()
		 */
		protected function playSlideInMovie(movie:MovieClip):void {
			movie._slide_.addEventListener(Event.ENTER_FRAME, handleSlideEnterFrame);
			this.loadingAnimation.visible = false;
			movie._isPlaying_ = true;
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
			this.applyTransitions(slide);
			
			// Find the next slide's movie, may be this movie if there's only 
			// one movie. May be null if the next movie is yet to load.
			var nextPlayIndex:uint = slide._movie_._playIndex_ > movieConfigs.length-2 ? 0 : slide._movie_._playIndex_ + 1;
			var nextMovie:MovieClip = null;
			for(var i:uint = 0 ; i < movies.numChildren ; i++) {
				var movie:MovieClip = movies.getChildAt(i) as MovieClip;
				if(movie._playIndex_ == nextPlayIndex) {
					nextMovie = movie;
				}
			}
			
			// If this is the final frame
			if(slide.currentFrame == slide.totalFrames) {
				// If this is the only movie, loop
				if(nextMovie == slide._movie_) {
					slide.gotoAndPlay(1);
				}
				else {
					// Pause
					slide.stop();
					// If the next movie is playing, reset this one
					if(nextMovie && nextMovie._isPlaying_) {
						slide.removeEventListener(Event.ENTER_FRAME, handleSlideEnterFrame);
						slide.gotoAndStop(1);
						slide._movie_._isPlaying_ = false;
						movies.setChildIndex(slide._movie_, 0);
					}
				}
			}
			// If it's time to play the next slide and it isn't playing
			if(slide.currentFrame >= slide.totalFrames - config.overlap) {
				// If it hasn't loaded, display the loading animation
				if(nextMovie == null) {
					loadingAnimation.visible = true;
				}
				if(nextMovie && !nextMovie._isPlaying_) {
					// Make sure it's under this one in stack and play
					movies.setChildIndex(nextMovie, movies.getChildIndex(slide._movie_)-1);
					playSlideInMovie(nextMovie);
				}
			}
		}
		
		/**
		 * Apply transitions based on configuration settings and current frame
		 * 
		 * @slide The MovieClip to apply transitions to
		 */
		 protected function applyTransitions(slide:MovieClip):void {
			
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
			
			// Movie may be hidden in anticipation of fade in
			slide.visible = true;
		 }
		
		/**
		 * Movie was clicked
		 */
		protected function movieClickHandler(movie:MovieClip):void {
			try {
				navigateToURL( new URLRequest(movie._href_), "_self" );
			}
			catch(e:Error) {}
		}
	}	
}
