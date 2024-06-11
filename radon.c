#include <fcntl.h>  // open
#include <unistd.h> // pwrite

#define pi 3.1415926535f

// bhaskara forumula, good approximation within [0,pi]
float sinf(float x) {
	return (16 * x * (pi - x)) / (5 * pi * pi - 4 * x * (pi - x));
}

// pade 4/4 approximant, good within [0,pi]
float cosf(float x) {
	float x2 = x * x, x4 = x2 * x2;
	return ((313.f / 15120.f) * x4 - (115.f / 252.f) * x2 + 1) / ((13.f / 15120.f) * x4 + (11.f / 252.f) * x2 + 1);
}

// indicator function
static float f(int x, int y) {
	// 400x100 center at 0,0
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
	if ((fb = open("/dev/fb0", O_RDWR)) < 0) return 1;

	unsigned char buf[wt*ht*ch] = {0};

	// f(x,y) in [0,1] specifies the density of the object
	// let radon transform = R(f(x,y)), convert (x,y) -> (s,u) by rotating through the origin by an angle z
	// then R(f(s,u)) = L[begin,end] f(s,u) du where L is a line integral
	// [begin,end] should be large enough to cover the extent of the object

	float z = 0;
	do {
		float zpi = z - pi * (int)(z / pi); // modulo pi
		float cs = cosf(zpi), sn = sinf(zpi), sum = 0;
		for (int x = wt-760; x > 760; x--) {
			for (int y = ht-340; y > 340; y--) {
				int s = (x-960) * cs + (y-540) * sn, u = (x-960) * -sn + (y-540) * cs;
				sum = 0.005f * (sum + f(s,u));
				buf[((int)(zt*z)+wt*y)*4+2] += 255u * sum; // sinogram
				//buf[(x+wt*y)*4+1] = 255u * f(s,u); // object
			}
		}
		pwrite(fb, buf, wt*ht*ch, 0);
		z += rot;
		if (zt * z > 1920) break;
	} while (1);

	return 0;
}
