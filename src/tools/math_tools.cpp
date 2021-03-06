#include "math_tools.h"
#include <math.h>
#include <assert.h>
#include <math.h>
#include <vector>
#include <stdio.h>

double gammaln(double x)
{
    double y,tmp,ser;
    static double cof[6] = {76.18009172947146,-86.50532032941677,24.01409824083091,-1.231739572450155,0.1208650973866179e-2,-0.5395239384953e-5 };

    y=x;
    tmp=x+5.5;
    tmp -= (x+0.5)*log(tmp);
    ser = 1.000000000190015;
    for (int j=0; j<=5; j++)
        ser+= cof[j]/++y;

    return -tmp+log(2.5066282746310005*ser/x);
}

double factln(int n)
{
    double ret;

    static double a[101]; // static array is automatically initialized to zero
    if (n<0)
	{
        printf("gammaln function only defined for positive values");
		assert(n>=0);
	}
    else if (n<=1)
        ret = 0;
    else if (n<=100)
        ret = a[n] ? a[n] : (a[n]=gammaln(n+1.0));
    else
        ret = gammaln(n+1);

	return ret;
}


double bino_pdf(int k, int n, float p)
{   
    double ln_binco = factln(n)-factln(k)-factln(n-k);
    double ln_ret = ln_binco + k*log(p) + (n-k)*log(1-p);
    return exp(ln_ret);
}

float bino_cfd(int cnt, int num, float p)
{

    // compute cdf
    float ret = 0;
    for (int i=0; i<=cnt; i++)
        ret+=bino_pdf(i, num, p);

	assert(ret<=1+1e-3);
    return ret;
}

template <typename T>
std::vector<T> prctile(std::vector<T> vec, std::vector<float> pos)
{
	sort(vec.begin(), vec.end());

	int max_pos = ((int) vec.size())-1;
	std::vector<T> ret;
	for (unsigned int i=0; i<pos.size(); i++)
	{
		int idx1 = floor(max_pos*pos[i]);
		int idx2 = ceil(max_pos*pos[i]);

		assert(idx1>=0);
		assert(idx2>=0);
		assert(idx1<=max_pos);
		assert(idx2<=max_pos);
	
		ret.push_back((vec[idx1]+vec[idx2])/2);
	}
	return ret;
}

