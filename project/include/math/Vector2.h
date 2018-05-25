#ifndef LIME_MATH_VECTOR2_H
#define LIME_MATH_VECTOR2_H


#include <hl.h>
#include <hx/CFFI.h>


namespace lime {
	
	
	struct HL_Vector2 {
		
		hl_type* t;
		double length;
		double x;
		double y;
		
	};
	
	
	class Vector2 {
		
		
		public:
			
			Vector2 ();
			Vector2 (double x, double y);
			Vector2 (value vec);
			
			value Value ();
			
			double x;
			double y;
		
		
	};
	
	
}


#endif