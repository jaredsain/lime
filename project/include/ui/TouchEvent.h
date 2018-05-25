#ifndef LIME_UI_TOUCH_EVENT_H
#define LIME_UI_TOUCH_EVENT_H


#include <hl.h>
#include <hx/CFFI.h>
#include <stdint.h>


namespace lime {
	
	
	enum TouchEventType {
		
		TOUCH_START,
		TOUCH_END,
		TOUCH_MOVE
		
	};
	
	
	struct HL_TouchEvent {
		
		hl_type* t;
		int device;
		double dx;
		double dy;
		int id;
		double pressure;
		TouchEventType type;
		double x;
		double y;
		
	};
	
	
	class TouchEvent {
		
		public:
			
			static AutoGCRoot* callback;
			static AutoGCRoot* eventObject;
			
			TouchEvent ();
			
			static void Dispatch (TouchEvent* event);
			
			uint32_t device;
			float dx;
			float dy;
			uint32_t id;
			float pressure;
			TouchEventType type;
			float x;
			float y;
		
	};
	
	
}


#endif