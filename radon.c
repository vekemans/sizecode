#include <math.h> // tanf, sinf, fmodf
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

#define wt 1920u
#define ht 1080u
#define ch 4
#define si 412 // sum iterations
#define tau 6.2831853f
#define rot 0.0175f // ~1 deg

#include <string.h>
int main() {
	int fb; // framebuffer fd
	if ((fb = open("/dev/fb0", O_RDWR)) < 0) {
		return 1;
	}

	unsigned char buf[wt*ht*ch];
	memset(buf, 0, sizeof buf);

	// f(x,y) in [0,1] specifies the density of the object
	// let radon transform = R(f(x,y)), convert (x,y) -> (s,u) by rotating through the origin by an angle z
	// then R(f(s,u)) = L[begin,end] f(s,u) du where L is a line integral
	// [begin,end] should be large enough to cover the extent of the object

	int const du = 48, ds = 48;
	float z = 0;
	do {
		float tn = -tanf(z * 0.5), sn = sinf(z);
		for (int x = wt-1; x > 0; x--) {
			for (int y = ht-1; y > 0; y--) {
				// rotation by shearing thrice
				// cohost.org/tomforsyth/post/891823-rotation-with-three
				int s = (x-960) * (1+tn*sn) + (y-540) * sn;
				int u = (x-960) * (2*tn+tn*tn*sn) + (y-540) * (1+sn*tn);
				float sum = 0;
				// FIXME evaluate grid covering extent of object
				// ie. grid is a fixed chunk of the screen
				// which means we need to rotate the grid rather than the object/screen (?)
				for (int i = 0; i < si; i += ds) {
					for (int j = 0; j < si; j += du) {
						sum += f(s-i,u-j);
					}
					//int q = 120*z; buf[(q+wt*i)*4+2] += 255u * sum; // sinogram
				}
				sum *= 1.0f / si; // [0,1]
				//int q = 120*z; buf[(q+wt*y)*4+2] += 255u * sum; // sinogram
				buf[(x+wt*y)*4+2] += 255u * sum; // disc
				//buf[(x+wt*y)*4+1] = 255u * f(s,u); // rotating object
				//buf[(x+wt*y)*4+0] = 255u * f(x-960,y-540); // centered object
			}
		}
		if (pwrite(fb, buf, wt*ht*ch, 0) < 0) {
			return 2;
		}
		z += rot;
	} while (1);

	return 0;
}
