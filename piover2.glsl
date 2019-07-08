#define PI radians(180.)
float clip(float a) { return clamp(a,-1.,1.); }
float theta(float x) { return smoothstep(0., 0.01, x); }
float _sin(float a) { return sin(2. * PI * mod(a,1.)); }
float _sin(float a, float p) { return sin(2. * PI * mod(a,1.) + p); }
float _unisin(float a,float b) { return (.5*_sin(a) + .5*_sin((1.+b)*a)); }
float _sq(float a) { return sign(2.*fract(a) - 1.); }
float _sq(float a,float pwm) { return sign(2.*fract(a) - 1. + pwm); }
float _psq(float a) { return clip(50.*_sin(a)); }
float _psq(float a, float pwm) { return clip(50.*(_sin(a) - pwm)); } 
float _tri(float a) { return (4.*abs(fract(a)-.5) - 1.); }
float _saw(float a) { return (2.*fract(a) - 1.); }
float quant(float a,float div,float invdiv) { return floor(div*a+.5)*invdiv; }
float quanti(float a,float div) { return floor(div*a+.5)/div; }
float freqC1(float note){ return 32.7 * pow(2.,note/12.); }
float minus1hochN(int n) { return (1. - 2.*float(n % 2)); }
float minus1hochNminus1halbe(int n) { return round(sin(.5*PI*float(n))); }
float pseudorandom(float x) { return fract(sin(dot(vec2(x),vec2(12.9898,78.233))) * 43758.5453); }

#define pat4(a,b,c,d,x) mod(x,1.)<.25 ? a : mod(x,1.)<.5 ? b : mod(x,1.) < .75 ? c : d

const float BPM = 80.;
const float BPS = BPM/60.;
const float SPB = 60./BPM;

const float Fsample = 44100.; // I think?
const float Tsample = 1./Fsample;

const float filterthreshold = 1e-3;

float doubleslope(float t, float a, float d, float s)
{
    return smoothstep(-.00001,a,t) - (1.-s) * smoothstep(0.,d,t-a);
}

float env_AHD(float t, float a, float h, float d)
{
    return t<a ? t/a : t<a+h ? 1. : t < a+h+d ? 1.+(1.-t)*(a+h)/d : 0.;
}

float env_ADSR(float x, float L, float A, float D, float S, float R)
{
    float att = x/A;
    float dec = 1. - (1.-S)*(x-A)/D;
    float rel = (x <= L-R) ? 1. : (L-x)/R;
    return x<A ? att : x<A+D ? dec : x<= L-R ? S : x<=L ? (L-x)/R : 0.;
}

float env_ADSRexp(float x, float L, float A, float D, float S, float R)
{
    float att = pow(x/A,8.);
    float dec = S + (1.-S) * exp(-(x-A)/D);
    float rel = (x <= L-R) ? 1. : pow((L-x)/R,4.);
    return (x < A ? att : dec) * rel;    
}

float s_atan(float a) { return 2./PI * atan(a); }
float s_crzy(float amp) { return clamp( s_atan(amp) - 0.1*cos(0.9*amp*exp(amp)), -1., 1.); }
float squarey(float a, float edge) { return abs(a) < edge ? a : floor(4.*a+.5)*.25; } 

float waveshape(float s, float amt, float A, float B, float C, float D, float E)
{
    float w;
    float m = sign(s);
    s = abs(s);

    if(s<A) w = B * smoothstep(0.,A,s);
    else if(s<C) w = C + (B-C) * smoothstep(C,A,s);
    else if(s<=D) w = s;
    else if(s<=1.)
    {
        float _s = (s-D)/(1.-D);
        w = D + (E-D) * (1.5*_s*(1.-.33*_s*_s));
    }
    else return 1.;
    
    return m*mix(s,w,amt);
}

float GAC(float t, float offset, float a, float b, float c, float d, float e, float f, float g)
{
    t = t - offset;
    return t<0. ? 0. : a + b*t + c*t*t + d*sin(e*t) + f*exp(-g*t);
}

float comp_SAW(int N, float inv_N) {return inv_N * minus1hochN(N);}
float comp_TRI(int N, float inv_N) {return N % 2 == 0 ? 0. : inv_N * inv_N * minus1hochNminus1halbe(N);}
float comp_SQU(int N, float inv_N, float PW) {return N % 2 == 0 ? 0. : inv_N * (1. - minus1hochNminus1halbe(N))*_sin(PW);}
float comp_HAE(int N, float inv_N, float PW) {return N % 2 == 0 ? 0. : inv_N * (minus1hochN(N)*_sin(PW*float(N)+.25) - 1.);}

float MACESQ(float t, float f, float phase, int NMAX, int NINC, float MIX, float CO, float NDECAY, float RES, float RES_Q, float DET, float PW, int keyF)
{
    float ret = 0.;
    float INR = keyF==1 ? 1./CO : f/CO;
    float IRESQ = keyF==1 ? 1./RES_Q : 1./(RES_Q*f);
    
    float p = f*t + phase;
    for(int N=1; N<=NMAX; N+=NINC)
    {
        float float_N = float(N);
        float inv_N = 1./float_N;
        float comp_mix = MIX < 0. ? (MIX+1.) * comp_TRI(N,inv_N)    +  (-MIX)  * comp_SAW(N,inv_N)
                       : MIX < 1. ?   MIX    * comp_TRI(N,inv_N)    + (1.-MIX) * comp_SQU(N,inv_N,PW)
                                  : (MIX-1.) * comp_HAE(N,inv_N,PW) + (2.-MIX) * comp_SQU(N,inv_N,PW);

        float filter_N = pow(1. + pow(float_N*INR,NDECAY),-.5) + RES * exp(-pow((float_N*f-CO)*IRESQ,2.));
        
        if(abs(filter_N*comp_mix) < 1e-6) break; //or is it wise to break already?
        
        ret += comp_mix * filter_N * (_sin(float_N * p) + _sin(float_N * p * (1.+DET)));
    }
    return s_atan(ret);
}

float resolpFsaw(float time, float f, float tL, float fa, float reso) // CHEERS TO metabog https://www.shadertoy.com/view/XljSD3 - thanks for letting me steal
{
    int maxTaps = 128;
    fa = sqrt(fa*Tsample);
    float c = pow(0.5, (128.0-fa*128.0)  / 16.0);
    float r = 1. - c*pow(0.5, (reso*128.0+24.0) / 16.0);
    
    float v0 = 0.;
    float v1 = 0.;
    
    for(int i = 0; i < maxTaps; i++)
    {
          float _TIME = time - float(maxTaps-i)*Tsample;
          //float _TIME*SPB = _TIME * BPS; //do I need that?
          float inp = (2.*fract(f*_TIME+0.)-1.);
          v0 = r*v0 - c*v1 + c*inp;
          v1 = r*v1 + c*v0;
    }
    return v1;
}
float combFsaw2(float time, float f, float tL, float IIR_gain, float IIR_N, float FIR_gain, float FIR_N)
{
    int imax = int(log(filterthreshold)/log(IIR_gain));
    float sum = 0.;
    float fac = 1.;
    
    float Tback = IIR_N*Tsample;
    float Tfwd = FIR_N*Tsample;
    
    for(int i = 0; i < imax; i++)
    {
        float _TIME = time - float(i)*Tback;
          sum += fac * ((.5+(.5*_psq(8.*_TIME*SPB,0.)))*(2.*fract(f*_TIME+0.)-1.));
          _TIME -= Tfwd;
          sum += fac * FIR_gain * ((.5+(.5*_psq(8.*_TIME*SPB,0.)))*(2.*fract(f*_TIME+0.)-1.));
          fac *= -IIR_gain;
    }
    return sum;
}
float reverbFsaw3_IIR(float time, float f, float tL, float IIRgain, float IIRdel1, float IIRdel2, float IIRdel3, float IIRdel4)
{
    int imax = int(log(filterthreshold)/log(IIRgain));
    float delay[4] = float[4](IIRdel1, IIRdel2, IIRdel3, IIRdel4);
    
    float sum = 0.;
    
    // 4 IIR comb filters
    for(int d=0; d<8; d++)
    {
        float fac = 1.;
        
        for(int i=0; i<imax; i++)
        {
            float _TIME = time - float(i)*delay[d] * (.8 + .4*pseudorandom(sum));
            sum += fac*(theta(_TIME*SPB)*exp(-8.*_TIME*SPB)*((.5+(.5*_psq(8.*_TIME*SPB,0.)))*(2.*fract(f*_TIME+0.)-1.)));
            fac *= -IIRgain;
        }
    }
    return .25*sum;
}

float reverbFsaw3_AP1(float time, float f, float tL, float IIRgain, float IIRdel1, float IIRdel2, float IIRdel3, float IIRdel4, float APgain, float APdel1)
{
    // first allpass delay line
    float _TIME = time;
    float sum = -APgain * reverbFsaw3_IIR(_TIME, f, tL, IIRgain, IIRdel1, IIRdel2, IIRdel3, IIRdel4);
    float fac = 1. - APgain * APgain;
    
    int imax = 1 + int((log(filterthreshold)-log(fac))/log(APgain));
    
    for(int i=0; i<imax; i++)
    {
        _TIME -= APdel1 * (.9 + 0.2*pseudorandom(time));
        sum += fac * reverbFsaw3_IIR(_TIME, f, tL, IIRgain, IIRdel1, IIRdel2, IIRdel3, IIRdel4);
        fac *= APgain * (1. + 0.01*pseudorandom(_TIME));
    }
    return sum;        
}

float reverbFsaw3(float time, float f, float tL, float IIRgain, float IIRdel1, float IIRdel2, float IIRdel3, float IIRdel4, float APgain, float APdel1, float APdel2)
{   // // based on this Schroeder Reverb from Paul Wittschen: http://www.paulwittschen.com/files/schroeder_paper.pdf
    // todo: add some noise...
    // second allpass delay line
    float _TIME = time;
    float sum = -APgain * reverbFsaw3_AP1(_TIME, f, tL, IIRgain, IIRdel1, IIRdel2, IIRdel3, IIRdel4, APgain, APdel1);
    float fac = 1. - APgain * APgain;

    int imax = 1 + int((log(filterthreshold)-log(fac))/log(APgain));

    for(int i=0; i<imax; i++)
    {
        _TIME -= APdel2 * (.9 + 0.2*pseudorandom(time));
        sum += fac * reverbFsaw3_AP1(_TIME, f, tL, IIRgain, IIRdel1, IIRdel2, IIRdel3, IIRdel4, APgain, APdel1);
        fac *= APgain * (1. + 0.01*pseudorandom(_TIME));
    }
    return sum;        
}
float resolpFstr(float time, float f, float tL, float fa, float reso) // CHEERS TO metabog https://www.shadertoy.com/view/XljSD3 - thanks for letting me steal
{
    int maxTaps = 128;
    fa = sqrt(fa*Tsample);
    float c = pow(0.5, (128.0-fa*128.0)  / 16.0);
    float r = 1. - c*pow(0.5, (reso*128.0+24.0) / 16.0);
    
    float v0 = 0.;
    float v1 = 0.;
    
    for(int i = 0; i < maxTaps; i++)
    {
          float _TIME = time - float(maxTaps-i)*Tsample;
          //float _TIME*SPB = _TIME * BPS; //do I need that?
          float inp = s_atan((2.*fract((f+.3*(.5+(.5*_sin(5.*_TIME*SPB)))*env_ADSR(_TIME,tL,.2,.3,.8,.2))*_TIME+0.)-1.)+(2.*fract((1.-.01)*(f+.3*(.5+(.5*_sin(5.*_TIME*SPB)))*env_ADSR(_TIME,tL,.2,.3,.8,.2))*_TIME+0.)-1.)+(2.*fract((1.-.011)*(f+.3*(.5+(.5*_sin(5.*_TIME*SPB)))*env_ADSR(_TIME,tL,.2,.3,.8,.2))*_TIME+0.)-1.)+(2.*fract((1.+.02)*(f+.3*(.5+(.5*_sin(5.*_TIME*SPB)))*env_ADSR(_TIME,tL,.2,.3,.8,.2))*_TIME+0.)-1.));
          v0 = r*v0 - c*v1 + c*inp;
          v1 = r*v1 + c*v0;
    }
    return v1;
}
float reverbsnrrev_IIR(float time, float f, float tL, float IIRgain, float IIRdel1, float IIRdel2, float IIRdel3, float IIRdel4)
{
    int imax = int(log(filterthreshold)/log(IIRgain));
    float delay[4] = float[4](IIRdel1, IIRdel2, IIRdel3, IIRdel4);
    
    float sum = 0.;
    
    // 4 IIR comb filters
    for(int d=0; d<8; d++)
    {
        float fac = 1.;
        
        for(int i=0; i<imax; i++)
        {
            float _TIME = time - float(i)*delay[d] * (.8 + .4*pseudorandom(sum));
            sum += fac*clamp(1.6*_tri(_TIME*(350.+(6000.-800.)*smoothstep(-.01,0.,-_TIME)+(800.-350.)*smoothstep(-.01-.01,-.01,-_TIME)))*smoothstep(-.1,-.01-.01,-_TIME) + .7*fract(sin(_TIME*90.)*4.5e4)*doubleslope(_TIME,.05,.3,.3),-1., 1.)*doubleslope(_TIME,0.,.25,.3);
            fac *= -IIRgain;
        }
    }
    return .25*sum;
}

float reverbsnrrev_AP1(float time, float f, float tL, float IIRgain, float IIRdel1, float IIRdel2, float IIRdel3, float IIRdel4, float APgain, float APdel1)
{
    // first allpass delay line
    float _TIME = time;
    float sum = -APgain * reverbsnrrev_IIR(_TIME, f, tL, IIRgain, IIRdel1, IIRdel2, IIRdel3, IIRdel4);
    float fac = 1. - APgain * APgain;
    
    int imax = 1 + int((log(filterthreshold)-log(fac))/log(APgain));
    
    for(int i=0; i<imax; i++)
    {
        _TIME -= APdel1 * (.9 + 0.2*pseudorandom(time));
        sum += fac * reverbsnrrev_IIR(_TIME, f, tL, IIRgain, IIRdel1, IIRdel2, IIRdel3, IIRdel4);
        fac *= APgain * (1. + 0.01*pseudorandom(_TIME));
    }
    return sum;        
}

float reverbsnrrev(float time, float f, float tL, float IIRgain, float IIRdel1, float IIRdel2, float IIRdel3, float IIRdel4, float APgain, float APdel1, float APdel2)
{   // // based on this Schroeder Reverb from Paul Wittschen: http://www.paulwittschen.com/files/schroeder_paper.pdf
    // todo: add some noise...
    // second allpass delay line
    float _TIME = time;
    float sum = -APgain * reverbsnrrev_AP1(_TIME, f, tL, IIRgain, IIRdel1, IIRdel2, IIRdel3, IIRdel4, APgain, APdel1);
    float fac = 1. - APgain * APgain;

    int imax = 1 + int((log(filterthreshold)-log(fac))/log(APgain));

    for(int i=0; i<imax; i++)
    {
        _TIME -= APdel2 * (.9 + 0.2*pseudorandom(time));
        sum += fac * reverbsnrrev_AP1(_TIME, f, tL, IIRgain, IIRdel1, IIRdel2, IIRdel3, IIRdel4, APgain, APdel1);
        fac *= APgain * (1. + 0.01*pseudorandom(_TIME));
    }
    return sum;        
}
float resolpA1oscmixF(float time, float f, float tL, float fa, float reso) // CHEERS TO metabog https://www.shadertoy.com/view/XljSD3 - thanks for letting me steal
{
    int maxTaps = 128;
    fa = sqrt(fa*Tsample);
    float c = pow(0.5, (128.0-fa*128.0)  / 16.0);
    float r = 1. - c*pow(0.5, (reso*128.0+24.0) / 16.0);
    
    float v0 = 0.;
    float v1 = 0.;
    
    for(int i = 0; i < maxTaps; i++)
    {
          float _TIME = time - float(maxTaps-i)*Tsample;
          //float _TIME*SPB = _TIME * BPS; //do I need that?
          float inp = waveshape((s_atan(_sq(.25*f*_TIME,.2*(2.*fract(2.*f*_TIME+.4*_tri(.5*f*_TIME+0.))-1.))+_sq((1.-.004)*.25*f*_TIME,.2*(2.*fract(2.*f*_TIME+.4*_tri(.5*f*_TIME+0.))-1.)))+.8*(2.*fract(2.*f*_TIME+.4*_tri(.5*f*_TIME+0.))-1.)),(2.*fract(2.*f*_TIME+.4*_tri(.5*f*_TIME+0.))-1.),.1,.3,.3,.8,.8);
          v0 = r*v0 - c*v1 + c*inp;
          v1 = r*v1 + c*v0;
    }
    return v1;
}
float resolpA24_lp(float time, float f, float tL, float fa, float reso) // CHEERS TO metabog https://www.shadertoy.com/view/XljSD3 - thanks for letting me steal
{
    int maxTaps = 128;
    fa = sqrt(fa*Tsample);
    float c = pow(0.5, (128.0-fa*128.0)  / 16.0);
    float r = 1. - c*pow(0.5, (reso*128.0+24.0) / 16.0);
    
    float v0 = 0.;
    float v1 = 0.;
    
    for(int i = 0; i < maxTaps; i++)
    {
          float _TIME = time - float(maxTaps-i)*Tsample;
          //float _TIME*SPB = _TIME * BPS; //do I need that?
          float inp = (.7*(.5+(.5*clip(2.5*(fract(16.*_TIME*SPB+0.)+0.))))*(2.*fract(.99*f*_TIME+0.)-1.)+.7*(.5+(.5*clip(2.5*(fract(16.*_TIME*SPB+0.)+0.))))*_sq(.5*f*_TIME,.2)+.7*(.5+(.5*clip(2.5*(fract(16.*_TIME*SPB+0.)+0.))))*_sin(.48*f*_TIME,.25)+-.35);
          v0 = r*v0 - c*v1 + c*inp;
          v1 = r*v1 + c*v0;
    }
    return v1;
}


float karplusstrong(float time, float f)
{
    float u = f * f * (3.0 - 2.0 * f ); // custom cubic curve
    return mix(pseudorandom(time), pseudorandom(time+1.), u);
}

float bitexplosion(float time, float B, int dmaxN, float fvar, float B2amt, float var1, float var2, float var3, float decvar)
{
    float snd = 0.;
    float B2 = mod(B,2.);
    float f = 60.*fvar;
	float dt = var1 * 2.*PI/15. * B/sqrt(10.*var2-.5*var3*B);
    int maxN = 10 + dmaxN;
    for(int i=0; i<2*maxN+1; i++)
    {
        float t = time + float(i - maxN)*dt;
        snd += _sin(f*t + .5*(1.+B2amt*B2)*_sin(.5*f*t));
    }
    float env = exp(-2.*decvar*B);
    return atan(snd * env);
}

float AMAYSYN(float t, float B, float Bon, float Boff, float note, int Bsyn, float Brel)
{
    float Bprog = B-Bon;
    float Bproc = Bprog/(Boff-Bon);
    float L = Boff-Bon;
    float tL = SPB*L;
    float _t = SPB*(B-Bon);
    float f = freqC1(note);
	float vel = 1.; //implement later

    float env = theta(B-Bon) * (1. - smoothstep(Boff, Boff+Brel, B));
	float s = _sin(t*f);

	if(Bsyn == 0){}
    else if(Bsyn == 7){
      s = karplusstrong(_t,f);}
    
    
	return clamp(env,0.,1.) * s_atan(s);
}

float BA8(float x, int pattern)
{
    x = mod(x,1.);
    float ret = 0.;
	for(int b = 0; b < 8; b++)
    	if ((pattern & (1<<b)) > 0) ret += step(x,float(7-b)/8.);
    return ret * .125;
}

float mainSynth(float time)
{
    int NO_trks = 1;
    int trk_sep[2] = int[2](0,1);
    int trk_syn[1] = int[1](7);
    float trk_norm[1] = float[1](.9);
    float trk_rel[1] = float[1](0.);
    float mod_on[1] = float[1](0.);
    float mod_off[1] = float[1](8.);
    int mod_ptn[1] = int[1](0);
    float mod_transp[1] = float[1](0.);
    float max_mod_off = 10.;
    int drum_index = 23;
    float drum_synths = 9.;
    int NO_ptns = 1;
    int ptn_sep[2] = int[2](0,17);
    float note_on[17] = float[17](0.,1.,1.5,2.,2.5,3.,4.,4.,4.5,4.5,5.,5.5,5.5,6.,6.5,7.,7.5);
    float note_off[17] = float[17](1.,1.5,2.,2.5,3.,4.,4.5,4.5,5.,5.,5.5,6.,6.,7.,7.,8.,8.);
    float note_pitch[17] = float[17](31.,35.,33.,36.,33.,27.,50.,35.,33.,49.,36.,39.,45.,28.,40.,24.,39.);
    float note_vel[17] = float[17](1.,1.,1.,1.,1.,1.,1.,1.,1.,1.,1.,1.,1.,1.,1.,1.,1.);
    
    float r = 0.;
    float d = 0.;

    // mod for looping
    float BT = mod(BPS * time, max_mod_off);
    if(BT > max_mod_off) return r;
    time = SPB * BT;

    float r_sidechain = 1.;

    float Bon = 0.;
    float Boff = 0.;

    for(int trk = 0; trk < NO_trks; trk++)
    {
        int TLEN = trk_sep[trk+1] - trk_sep[trk];

        int _modU = TLEN-1;
        for(int i=0; i<TLEN-1; i++) if(BT < mod_on[(trk_sep[trk]+i)]) {_modU = i; break;}
               
        int _modL = TLEN-1;
        for(int i=0; i<TLEN-1; i++) if(BT < mod_off[(trk_sep[trk]+i)] + trk_rel[trk]) {_modL = i; break;}
       
        for(int _mod = _modL; _mod <= _modU; _mod++)
        {
            float B = BT - mod_on[trk_sep[trk]+_mod];

            int ptn = mod_ptn[trk_sep[trk]+_mod];
            int PLEN = ptn_sep[ptn+1] - ptn_sep[ptn];
           
            int _noteU = PLEN-1;
            for(int i=0; i<PLEN-1; i++) if(B < note_on[(ptn_sep[ptn]+i+1)]) {_noteU = i; break;}

            int _noteL = PLEN-1;
            for(int i=0; i<PLEN-1; i++) if(B <= note_off[(ptn_sep[ptn]+i)] + trk_rel[trk]) {_noteL = i; break;}
           
            for(int _note = _noteL; _note <= _noteU; _note++)
            {
                Bon    = note_on[(ptn_sep[ptn]+_note)];
                Boff   = note_off[(ptn_sep[ptn]+_note)];

                if(trk_syn[trk] == drum_index)
                {
                    int Bdrum = int(mod(note_pitch[ptn_sep[ptn]+_note], drum_synths));
                    float Bvel = note_vel[(ptn_sep[ptn]+_note)] * pow(2.,mod_transp[trk_sep[trk]+_mod]/6.);

                    //0 is for sidechaining - am I doing this right?
                    if(Bdrum == 0)
                        r_sidechain = (1. - theta(B-Bon) * exp(-1000.*(B-Bon))) * smoothstep(Bon,Boff,B);
                    else
                        d += trk_norm[trk] * AMAYSYN(time, B, Bon, Boff, Bvel, -Bdrum, trk_rel[trk]);
                }
                else
                {
                    r += trk_norm[trk] * AMAYSYN(time, B, Bon, Boff,
                                                   note_pitch[(ptn_sep[ptn]+_note)] + mod_transp[trk_sep[trk]+_mod], trk_syn[trk], trk_rel[trk]);
                }
            }
        }
    }

    return s_atan(s_atan(r_sidechain * r + d));
}

vec2 mainSound(float t)
{
    //enhance the stereo feel
    float stereo_delay = 2e-4;
      
    return vec2(mainSynth(t), mainSynth(t-stereo_delay));
}
