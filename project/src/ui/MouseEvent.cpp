#include <system/CFFI.h>
#include <ui/MouseEvent.h>


namespace lime {
	
	
	ValuePointer* MouseEvent::callback = 0;
	ValuePointer* MouseEvent::eventObject = 0;
	
	static int id_button;
	static int id_movementX;
	static int id_movementY;
	static int id_type;
	static int id_windowID;
	static int id_x;
	static int id_y;
	static bool init = false;
	
	
	MouseEvent::MouseEvent () {
		
		button = 0;
		type = MOUSE_DOWN;
		windowID = 0;
		x = 0.0;
		y = 0.0;
		movementX = 0.0;
		movementY = 0.0;
		
	}
	
	
	void MouseEvent::Dispatch (MouseEvent* event) {
		
		if (MouseEvent::callback) {
			
			if (MouseEvent::eventObject->IsCFFIValue ()) {
				
				if (!init) {
					
					id_button = val_id ("button");
					id_movementX = val_id ("movementX");
					id_movementY = val_id ("movementY");
					id_type = val_id ("type");
					id_windowID = val_id ("windowID");
					id_x = val_id ("x");
					id_y = val_id ("y");
					init = true;
					
				}
				
				value object = (value)MouseEvent::eventObject->Get ();
				
				if (event->type != MOUSE_WHEEL) {
					
					alloc_field (object, id_button, alloc_int (event->button));
					
				}
				
				alloc_field (object, id_movementX, alloc_float (event->movementX));
				alloc_field (object, id_movementY, alloc_float (event->movementY));
				alloc_field (object, id_type, alloc_int (event->type));
				alloc_field (object, id_windowID, alloc_int (event->windowID));
				alloc_field (object, id_x, alloc_float (event->x));
				alloc_field (object, id_y, alloc_float (event->y));
				
			} else {
				
				HL_MouseEvent* eventObject = (HL_MouseEvent*)MouseEvent::eventObject->Get ();
				
				eventObject->movementX = event->movementX;
				eventObject->movementY = event->movementY;
				eventObject->type = event->type;
				eventObject->windowID = event->windowID;
				eventObject->x = event->x;
				eventObject->y = event->y;
				
			}
			
			MouseEvent::callback->Call ();
			
		}
		
	}
	
	
}