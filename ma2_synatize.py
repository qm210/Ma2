#import math
from random import random

GLfloat = lambda f: str(int(f)) + '.' if f==int(f) else str(f)[0 if f>=1 or f<0 else 1:].replace('-0.','-.')

def GLstr(s):
    try:
        f = float(s)
    except ValueError:
        return s
    else:
        return GLfloat(f)

#reserved keywords you cannot name a form after ~ f,t are essential, and maybe we want to use the other
_f = {'ID':'f', 'type':'uniform'}
_t = {'ID':'t', 'type':'uniform'}
_t_ = {'ID':'_t', 'type':'uniform'}
_B = {'ID':'B', 'type':'uniform'}
_vel = {'ID':'vel', 'type':'uniform'}
_Bsyn = {'ID':'Bsyn', 'type':'uniform'}
_Bproc = {'ID':'Bproc', 'type':'uniform'}
_Bprog = {'ID':'Bprog', 'type':'uniform'}
_L = {'ID':'L', 'type':'uniform'}
_tL = {'ID':'tL', 'type':'uniform'}
_SPB = {'ID':'SPB', 'type':'uniform'}
_BPS = {'ID':'BPS', 'type':'uniform'}
_BPM = {'ID':'BPM', 'type':'uniform'}
_note = {'ID':'note', 'type':'uniform'}
_Fsample = {'ID':'Fsample', 'type':'uniform'}

newlineplus = '\n'+6*' '+'+'

def synatize(syn_file = 'test.syn'):

    syncode = ""

    form_list = [_f, _t, _t_, _B, _vel, _Bsyn, _Bproc, _Bprog, _L, _tL, _SPB, _BPS, _BPM, _note, _Fsample]
    main_list = []
   
    print('READING', './' + syn_file + ':')
   
    with open(syn_file,"r") as template:
        lines = template.readlines()
        
    for l in lines:
        if l=='\n' or l[0]=='#': continue
    
        line = l.split()
        cmd = line[0].lower()
        cid = line[1]
        arg = line[2:]
        
        # small sanity check for number of arguments
        try:
            assert len(line) >= arg_required(cmd, arg)
        except AssertionError as e:
            print('ERROR! THIS LINE DOES NOT MATCH THE NUMBER OF REQUIRED ARGUMENTS:', l, 'REQUIRES: '+str(arg_required(cmd, arg))+' ARGUMENTS.', sep='\n')
            quit()
        
       
        if cid in [f['ID'] for f in form_list]:
            print(' -> ERROR! ID \"' + cid + '\" already taken. Ignoring line.')
            continue

        if cmd == 'main' or cmd == 'maindrum':
            main_list.append({'ID':cid, 'type':cmd, 'amount':len(line)-2, 'terms':arg})

        elif cmd == 'const':
            form_list.append({'ID':cid, 'type':cmd, 'value':float(arg[0])})
    
        elif cmd == 'random':
            rand_min = float(arg[0])
            rand_max = float(arg[1])
            digits = int(arg[2]) if len(arg)>2 else 3
            form_list.append({'ID':cid, 'type':cmd, 'value':round(rand_min+(rand_max-rand_min)*random(),digits)})
    
        elif cmd == 'osc' or cmd == 'lfo':
            form_list.append({'ID':cid, 'type':cmd, 'shape':arg[0].lower(), 'freq':arg[1], 'phase':arg[2] if len(arg)>2 else '0', 'par':arg[3:] if len(arg)>3 else []})

        elif cmd == 'drum':
            form_list.append({'ID':cid, 'type':cmd, 'shape':arg[0].lower(), 'par':arg[1:]})

        elif cmd == 'env':
            shape = arg[0].lower()
            form = {'ID':cid, 'type':cmd, 'shape':shape}
            
            if shape == 'adsr' or shape == 'adsrexp':
                form.update({'attack':arg[1], 'decay':arg[2], 'sustain':arg[3], 'release':arg[4], 'par':arg[5:] if len(arg)>5 else []})
            elif shape == 'doubleslope':
                form.update({'attack':arg[1], 'decay':arg[2], 'sustain':arg[3], 'par':arg[4] if len(arg)>4 else ''})
            elif shape == 'ss':
                form.update({'attack':arg[1], 'par':arg[2] if len(arg)>2 else ''})
            elif shape == 'ssdrop':
                form.update({'decay':arg[1], 'par':arg[2] if len(arg)>2 else ''})
            elif shape == 'expdecay' or shape == 'expdecayrepeat':
                form.update({'decay':arg[1], 'par':arg[2] if len(arg)>2 else ''})
            else:
                pass
            
            form_list.append(form)

        elif cmd == 'filter':
            form_list.append({'ID':cid, 'type':cmd, 'shape':arg[0].lower(), 'source':arg[1], 'par':arg[2:]})

        # generic automation curve - implemented just basic for now, let's think of something great some other time
        elif cmd == 'gac':
            form_list.append({'ID':cid, 'type':cmd, 'par':arg})

        # advanced forms ("operators"), like detune, chorus, delay, waveshaper/distortion, and more advanced: filter, reverb/*vec2 mainSound( float time )
        elif cmd == 'form':
            op = arg[0].lower()
            form = {'ID':cid, 'type':cmd, 'OP':op}

            if op == 'mix':
                form.update({'amount':len(arg), 'terms':arg[1:]})
            elif op == 'detune':
                form.update({'source':arg[1], 'amount':arg[2:]})
            elif op == 'pitchshift':
                form.update({'source':arg[1], 'steps':arg[2]})
            elif op == 'quantize':
                form.update({'source':arg[1], 'quant':arg[2]})
            elif op == 'overdrive':
                form.update({'source':arg[1], 'gain':arg[2]})
            elif op == 'chorus':
                form.update({'source':arg[1], 'number':arg[2], 'delay':arg[3]})
            elif op == 'delay':
                form.update({'source':arg[1], 'number':arg[2], 'delay':arg[3], 'decay':arg[4]})
            elif op == 'waveshape':
                form.update({'source':arg[1], 'par':arg[2:8]})
            elif op == 'saturate':
                form.update({'source':arg[1], 'gain':arg[2], 'mode':arg[3] if len(arg)>3 else 'default'})
            else:
                pass
                
            form_list.append(form)

    drum_list = [d['ID'] for d in main_list if d['type']=='maindrum']

    return form_list, main_list, drum_list


def synatize_build(form_list, main_list):

    def instance(ID, mod={}):
        
        form = next((f for f in form_list if f['ID']==ID), None)
        
        if mod:
            form = form.copy()
            form.update(mod)
        
        if '*' in ID:
            IDproduct = ID.split('*')
            product = ''
            for factorID in IDproduct:
                product += instance(factorID) + ('*' if factorID != IDproduct[-1] else '')
            return product;

        elif not form:
            return GLstr(ID).replace('--','+')
        
        elif form['type']=='uniform':
            return ID
        
        elif form['type']=='const' or form['type']=='random':
            return GLfloat(form['value'])
        
        elif form['type']=='form':
            if form['OP'] == 'mix':
                return '(' + '+'.join([instance(f) for f in form['terms']]) + ')' 
            elif form['OP'] == 'detune':
                detuned_instances = '+'.join(instance(form['source'],{'freq':'(1.-' + instance(amt) + ')*'+param(form['source'],'freq')}) for amt in form['amount']) 
                return 's_atan(' + instance(form['source']) + '+' + detuned_instances + ')'
            elif form['OP'] == 'pitchshift':
                return instance(form['source'],{'freq':'{:.4f}'.format(pow(2,float(form['steps'])/12)) + '*' + param(form['source'],'freq')})
            elif form['OP'] == 'quantize':
                return instance(form['source']).replace('_TIME','floor('+instance(form['quant']) + '*_TIME+.5)/' + instance(form['quant']))
            elif form['OP'] == 'overdrive':
                return 'clip(' + instance(form['gain']) + '*' + instance(form['source']) + ')'
            elif form['OP'] == 'chorus': #not finished, needs study
                return '(' + newlineplus.join([instance(form['source']).replace('_TIME','(_TIME-'+'{:.1e}'.format(t*float(form['delay']))+')') for t in range(int(form['number']))]) + ')'
            elif form['OP'] == 'delay': #not finished, needs study
                return '(' + newlineplus.join(['{:.1e}'.format(pow(float(form['decay']),t)) + '*' + \
                                               instance(form['source']).replace('_PROG','(_PROG-'+'{:.1e}'.format(t*float(form['delay']))+')') for t in range(int(form['number']))]) + ')'
            elif form['OP'] == 'waveshape':
                print(form['par'])
                return 'supershape(' + instance(form['source']) + ',' + ','.join(instance(form['par'][p]) for p in range(6)) + ')'
            elif form['OP'] == 'saturate':
                if form['mode'] == 'crazy':
                    return 's_crzy('+instance(form['gain']) + '*' + instance(form['source']) + ')'
                else:
                    return 's_atan('+instance(form['gain']) + '*' + instance(form['source']) + ')'
            else:
                return '1.'

        elif form['type'] == 'osc' or form['type'] == 'lfo':

                if form['type'] == 'osc':
                    phi = instance(form['freq']) + '*_TIME'
                    pre = 'vel*'

                elif form['type'] == 'lfo':
                    tvar = '*Bprog' if 'global' not in form['par'] else '*B'
                    if 'time' in form['par']: tvar = '*_PROG' if 'global' not in form['par'] else '*_TIME'
                        
                    phi = instance(form['freq']) + tvar
                    pre = ''
                    if form['shape'] == 'squ': form['shape'] = 'psq'

                    
                if form['shape'] == 'sin':
                    if form['phase'] == '0':
                        return pre + '_sin(' + phi + ')'
                    else:
                        return pre + '_sin(' + phi + ',' + instance(form['phase']) + ')'
      
                elif form['shape'] == 'saw':
                    return pre + '(2.*fract(' + phi + '+' + instance(form['phase']) + ')-1.)'
                
                elif form['shape'] == 'squ':
                    if form['par'] == '0':
                        return pre + '_sq(' + phi + ')'
                    else:
                        return pre + '_sq(' + phi + ',' + instance(form['par'][0]) + ')'

                elif form['shape'] == 'psq':
                    if form['par'] == '0':
                        return pre + '_psq(' + phi + ')'
                    else:
                        return pre + '_psq(' + phi + ',' + instance(form['par'][0]) + ')'

                elif form['shape'] == 'tri':
                        return pre + '_tri(' + phi + '+' + instance(form['phase']) + ')'

                elif form['shape'] == 'macesq':
                        return 'MACESQ(_PROG,'+instance(form['freq']) + ',' + instance(form['phase']) + ',' + ','.join([instance(p) for p in form['par']]) + ')'

                else:
                    return '0.'

        elif form['type'] == 'drum':
            
                if form['shape'] == 'kick': # <start freq> <end freq> <freq decay time> <env attack time> <env decay time> <distortion> ...
                    freq_start = instance(form['par'][0])
                    freq_end = instance(form['par'][1])
                    freq_decay = instance(form['par'][2])
                    env_attack = instance(form['par'][3])
                    env_decay = instance(form['par'][4])
                    distortion = instance(form['par'][5])
                    click_amp = instance(form['par'][6])
                    click_delay = instance(form['par'][7])
                    click_timbre = instance(form['par'][8])

                    freq_env = '('+freq_start+'+('+freq_end+'-'+freq_start+')*smoothstep(-'+freq_decay+', 0.,-_PROG))'
                    amp_env = 'vel*(smoothstep(0.,'+env_attack+',_PROG)*smoothstep(-('+env_attack+'+'+env_decay+'),-'+env_attack+',-_PROG)'
                    return 's_atan('+amp_env+'*(clip('+distortion+'*_tri('+freq_env+'*_PROG))+_sin(.5*'+freq_env+'*_PROG)))+ '+click_amp+'*step(_PROG,'+click_delay+')*_sin(5000.*_PROG*'+click_timbre+'*_saw(1000.*_PROG*'+click_timbre+')))'
                
                elif form['shape'] == 'snare':
                    return 0.

                elif form['shape'] == 'fmnoise':
                    env_attack = instance(form['par'][0])
                    env_decay = instance(form['par'][1])
                    env_sustain = instance(form['par'][2])
                    FMtimbre1 = instance(form['par'][3])
                    FMtimbre2 = instance(form['par'][4])
                    return 'vel*fract(sin(_TIME*100.*'+FMtimbre1+')*50000.*'+FMtimbre2+')*doubleslope(_PROG,'+env_attack+','+env_decay+','+env_sustain+')'
                    
                elif form['shape'] == 'bitexplosion':
                    return 'vel*bitexplosion(_TIME, _BPROG, '+str(int(form['par'][0])) + ',' + ','.join(instance(form['par'][p]) for p in range(1,7)) + ')' 

        elif form['type']=='env':
            if form['shape'] == 'adsr':
                tvar = '_BPROG' if 'beat' in form['par'] else '_PROG'
                Lvar = 'L' if 'beat' in form['par'] else 'tL'
                return 'env_ADSR('+tvar+','+Lvar+','+instance(form['attack'])+','+instance(form['decay'])+','+instance(form['sustain'])+','+instance(form['release'])+')'
            elif form['shape'] == 'adsrexp':
                return 'env_ADSRexp(_PROG,tL,'+instance(form['attack'])+','+instance(form['decay'])+','+instance(form['sustain'])+','+instance(form['release'])+')'
            elif form['shape'] == 'doubleslope':
                return 'doubleslope(_PROG, '+instance(form['attack'])+','+instance(form['decay'])+','+instance(form['sustain'])+')'
            elif form['shape'] == 'ss':
                return 'smoothstep(0.,'+instance(form['attack'])+',_PROG)'
            elif form['shape'] == 'ssdrop':
                return 'theta('+'_PROG'+')*smoothstep('+instance(form['decay'])+',0.,_PROG)'
            elif form['shape'] == 'expdecay':
                return 'theta('+'_BPROG'+')*exp(-'+instance(form['decay'])+'*_BPROG)'
            elif form['shape'] == 'expdecayrepeat':
                return 'theta('+'_BPROG'+')*exp(-'+instance(form['decay'])+'*mod(_BPROG,'+instance(form['par'])+'))'                
            else:
                return '1.'

        elif form['type']=='gac':
            tvar = '_PROG'
            pars = [(form['par'][p] if len(form['par'])>p else '0') for p in range(9)]
            if 'global' in form['par']:
                tvar = '_TIME'
                pars.remove('global')
                
            return 'GAC('+tvar+',' + ','.join([instance(pars[p]) for p in range(8)]) + ')'

        elif form['type']=='filter':
            if form['shape']=='resolp':
                return 'resolp'+form['source']+'(_PROG,f,tL,'+instance(form['par'][0])+','+instance(form['par'][1])+')'

        else:
            return '1.'

    def param(ID, key):
        form = next((f for f in form_list if f['ID']==ID), None)
        try:
            value = form[key]
        except KeyError:
            return ''
        except TypeError:
            return ''
        else:
            return value

    if not main_list:
        print("WARNING: no main form defined! will return empty sound")
        syncode = "s = 0.; //some annoying weirdo forgot to define the main form!"

    else:
        if len(main_list)==1:
            syncode = "s = "
            for term in main_list[0]['terms']:
                syncode += instance(term) + (newlineplus if term != main_list[0]['terms'][-1] else ';')
           
        else:
            syncount = 1
            drumcount = 1
            syncode = 'if(Bsyn == 0){}\n' + 4*' '
            for form_main in main_list:
                if form_main['type']!='main': continue
                syncode += 'else if(Bsyn == ' + str(syncount) + '){\n' + 6*' ' + 's = '
                for term in form_main['terms']:
                    syncode += instance(term) + (newlineplus if term != form_main['terms'][-1] else ';')
                syncode += '}\n' + 4*' '
                syncount += 1
            
            syncode = syncode.replace('vel*','') # for now, disable this for the synths above (but not for the drums below)
            
            drumcount = 1
            for form_main in main_list:
                if form_main['type']!='maindrum': continue
                syncode += 'else if(Bsyn == -' + str(drumcount) + '){\n' + 6*' ' + 's = '
                for term in form_main['terms']:
                    syncode += instance(term) + (newlineplus if term != form_main['terms'][-1] else ';')
                syncode += '}\n' + 4*' '
                drumcount += 1

        syncode = syncode.replace('_TIME','t').replace('_PROG','_t').replace('_BPROG','Bprog').replace('e+00','')

    for r in (f for f in form_list if f['type']=='random'):
        print('RANDOM', r['ID'], '=', r['value'])

    print("\nBUILD SYN CODE:\n", 4*' '+syncode, sep="")

    filter_list = [f for f in form_list if f['type']=='filter']
    filtercode = '' 
    for form in filter_list:
        if form['shape']=='resolp':
            ff = open("framework.resolptemplate")
            ffcode = ff.read()
            ff.close()
            filtercode += ffcode.replace('TEMPLATE',form['source']).replace('INSTANCE',instance(form['source'])).replace('vel*','').replace('_PROG','_TIME')

    print("\nBUILD FILTER CODE:\n", filtercode, sep="")

    return syncode, filtercode


def arg_required(cmd, arg):
    arg0 = arg[0].lower()  
    req = 3

    if cmd == 'osc':
        req += 1
        if arg0 == 'squ' or arg0 == 'psq': req += 2
        if arg0 == 'macesq': req += 11
    elif cmd == 'lfo':
        pass
    # ... add on demand...
    elif cmd == 'random':
        req = 4
    
    return req

if __name__ == '__main__':
    synatize()