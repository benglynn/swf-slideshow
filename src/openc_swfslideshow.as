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
	import flash.net.*;
	import flash.utils.*;
	
	import mx.effects.easing.*;

	[SWF (frameRate="21", backgroundColor="0x000000", pageTitle="openc.swfslideshow")]
	
	public class openc_swfslideshow extends Sprite {
		
		/**
		 * Params
		 */
		private var numSlides:uint;
		private var CROSSFADE_DURATION:uint = 0;
		// Order to display slides in, may be 'source' (XML source order) or 'random'
		private var ORDER:String = "source";
		private var resourcesDirectory:String = "resources";
		
		/**
		 * Constructor
		 */
		public function openc_swfslideshow() {
			
			// Allow the resource directory to be overriden by a q/s param
			if(loaderInfo.parameters.hasOwnProperty('resourcesDirectory')) {
				resourcesDirectory = loaderInfo.parameters['resourcesDirectory'];
			}
			
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			
			var loader:URLLoader = new URLLoader();
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			loader.addEventListener(Event.COMPLETE, handleXMLLoadComplete);
			loader.load(new URLRequest(this.resourcesDirectory + '/config.xml'));
		}

		/**
		 * Configuration has loaded
		 */
		private function handleXMLLoadComplete(event:Event):void {

			try {
				var config:XML = new XML(event.target.data);
				
				// Look for crossfade configuration
				var crossfade:String = config.@crossfade[0];
				if(crossfade) {
					CROSSFADE_DURATION = parseInt(crossfade);
				}
				
				// Look for order configuration
				var order:String = config.@order[0];
				if(order) {
					ORDER = order;
				}
				
				numSlides = config.movie.length();
				var count:uint = 0;
				for each(var movie:XML in config.movie) {				
					
					var loader:Loader = new Loader();
					loader.contentLoaderInfo.addEventListener(
						Event.COMPLETE,
						function(sourceIndex:uint, href:String):Function {
							return function(e:Event):void {
								handleMovieComplete(e, sourceIndex, href);
							}
						}(count++, movie.@href[0])
					);
					
					var src:String = this.resourcesDirectory + "/" + movie.@src;
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
			
			//flash.external.ExternalInterface.call('window.location.replace', movie._href);

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
			if(ORDER == "random") {
				trace("Sorting at random");
				children.sort(function():Number {
					return Math.round(Math.random()*2)-1;
				});
			}
			else if(ORDER == "source") {
				children.sort(function(a:MovieClip, b:MovieClip):Number {
					return a._sourceIndex_ > b._sourceIndex_  ? -1 : 1;
				});
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
			
			// If reveal should begin
			if(slide.currentFrame > slide.totalFrames - CROSSFADE_DURATION) {
				var time:Number = CROSSFADE_DURATION - (slide.totalFrames - slide.currentFrame);
				var initialValue:Number = 1;
				var totalChange:Number = -1;
				slide.alpha = Exponential.easeIn(time, initialValue, totalChange, CROSSFADE_DURATION);
			}
			
			// If this is the last frame
			if(slide.currentFrame == slide.totalFrames) {
				slide.removeEventListener(Event.ENTER_FRAME, handleSlideEnterFrame);
				slide.gotoAndStop(1);
				setChildIndex(slide._movie_, 0);
				slide.alpha = 1;
				playTopSlide();
			}
		}
	}
	
}
