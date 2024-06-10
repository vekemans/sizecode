#include <math.h> // tanf, sinf
#include <fcntl.h> // open
#include <unistd.h> // pwrite

// indicator function
static float f(int x, int y) {
	// 400x100 center at 0,0 (clipped)
	if (-100 < x && x < 100 && -50 < y && y < 50) {
		return 1.0f;
	}
	return 0.0f;
}

// screen dimensions
#define wt 1920
#define ht 1080
#define ch 4

// it's important that 1-zt*rot is close to zero
// to minimize loss of precision when mapping z -> x
#define zt 114.6f    // z scaling
#define rot 0.00873f // rotation of ~0.5 deg per frame

#include <stdio.h>
int main() {
	int fb; // framebuffer fd
	if ((fb = open("/dev/fb0", O_RDWR)) < 0) {
		return 1;
	}

	unsigned char buf[wt*ht*ch] = {0};

	// f(x,y) in [0,1] specifies the density of the object
	// let radon transform = R(f(x,y)), convert (x,y) -> (s,u) by rotating through the origin by an angle z
	// then R(f(s,u)) = L[begin,end] f(s,u) du where L is a line integral
	// [begin,end] should be large enough to cover the extent of the object

	float z = 0;
	do {
		float tn = -tanf(z * 0.5), sn = sinf(z), sum = 0;
		for (int x = wt-760; x > 760; x--) {
			for (int y = ht-340; y > 340; y--) {
				// rotation by shearing thrice
				// cohost.org/tomforsyth/post/891823-rotation-with-three
				// TODO shear pixels without trig functions
				int s = (x-960) * (1+tn*sn) + (y-540) * sn, u = (x-960) * (2*tn+tn*tn*sn) + (y-540) * (1+sn*tn);
				sum = 0.005f * (sum + f(s,u));
				buf[((int)(zt*z)+wt*y)*4+2] += 255u * sum; // sinogram
				//buf[(x+wt*y)*4+1] = 255u * f(s,u); // object
			}
		}
		pwrite(fb, buf, wt*ht*ch, 0);
		z += rot;
		if (zt*z > 1920) break;
	} while (1);

	return 0;
}
