export const audioState = {
    isBoss: false,
    bossFilledCount: 0
};

let soundMuted = false;
try {
    soundMuted = localStorage.getItem('slime_sound_muted') === 'true';
} catch (e) {}

let soundVolume = 0.8;
try {
    if (localStorage.getItem('slime_sound_volume') !== null) {
        soundVolume = parseFloat(localStorage.getItem('slime_sound_volume')!);
    }
} catch(e) {}

export const SoundAPI = {
    isMuted: () => soundMuted,
    setMuted: (muted: boolean) => {
        soundMuted = muted;
        try { localStorage.setItem('slime_sound_muted', String(muted)); } catch (e) {}
    },
    getVolume: () => soundVolume,
    setVolume: (vol: number) => {
        soundVolume = Math.max(0, Math.min(1, vol));
        try { localStorage.setItem('slime_sound_volume', String(soundVolume)); } catch (e) {}
        SoundEffects.updateVolume();
    }
};

export class SoundEffects {
    private static ctx: AudioContext | null = null;
    private static nextBeatTime = 0;
    private static beatIndex = 0;
    private static masterGain: GainNode | null = null;

    static init() {
        if (soundMuted) return;
        try {
            if (!this.ctx) {
                this.ctx = new (window.AudioContext || (window as any).webkitAudioContext)();
            }
            if (this.ctx && this.ctx.state === 'suspended') {
                this.ctx.resume();
            }
            if (this.ctx && !this.masterGain) {
                this.masterGain = this.ctx.createGain();
                this.masterGain.connect(this.ctx.destination);
                this.masterGain.gain.setValueAtTime(soundVolume, this.ctx.currentTime);
            }
        } catch (e) {
            console.warn("Web Audio initialization failed", e);
        }
    }

    static getDestination(): AudioNode {
        this.init();
        if (this.ctx && this.masterGain) {
            return this.masterGain;
        }
        return this.ctx ? this.ctx.destination : { connect: () => {} } as any;
    }

    static updateVolume() {
        if (soundMuted) return;
        this.init();
        if (this.ctx && this.masterGain) {
            this.masterGain.gain.setTargetAtTime(soundVolume, this.ctx.currentTime, 0.05);
        }
    }

    static tickBgm() {
        if (soundMuted) {
            this.stopBgm();
            return;
        }
        this.init();
        if (!this.ctx) return;
        if (this.ctx.state === 'suspended') return;

        let currentTime = this.ctx.currentTime;
        if (this.nextBeatTime === 0) {
            this.nextBeatTime = currentTime;
        }

        // Schedule beats up to 100ms in advance
        while (this.nextBeatTime < currentTime + 0.1) {
            this.scheduleNextBeat();
        }
    }

    static scheduleNextBeat() {
        if (!this.ctx) return;
        let t = this.nextBeatTime;
        
        let isBoss = audioState.isBoss;
        let filledCount = audioState.bossFilledCount;
        
        // Dynamic speed based on boss stage phase!
        let speedMult = 1.0;
        if (isBoss) {
            if (filledCount >= 7) speedMult = 2.0;      // Phase 3 is extreme speed
            else if (filledCount >= 4) speedMult = 1.5; // Phase 2 is double fast
            else speedMult = 1.2;                       // Boss intro/Phase 1 is fast
        }
        
        let beatDuration = 0.28 / speedMult; // 280ms base duration
        let i = this.beatIndex % 16;
        
        // Atmospheric pad chords (long slow fade) played on beat 0 and 8
        if (i === 0 || i === 8) {
            let chord: number[] = [];
            if (isBoss) {
                // Tense progression (Gm -> Abm -> Gdim -> Abmaj)
                let cGroup = Math.floor(this.beatIndex / 8) % 4;
                if (cGroup === 0) chord = [98.00, 116.54, 146.83, 196.00]; // G3, Bb3, D4, G4
                else if (cGroup === 1) chord = [103.83, 123.47, 155.56, 207.65]; // Ab3, B3, Eb4, Ab4
                else if (cGroup === 2) chord = [98.00, 116.54, 138.59, 196.00]; // Gdim
                else chord = [103.83, 130.81, 155.56, 207.65]; // Abmaj
            } else {
                // Warm cave ambient progression (F minor -> Db major -> C minor -> Bb minor)
                let chordGroup = Math.floor(this.beatIndex / 8) % 4;
                if (chordGroup === 0) chord = [87.31, 104.82, 130.81, 174.61]; // F minor
                else if (chordGroup === 1) chord = [69.30, 87.31, 103.83, 138.59]; // Db Major
                else if (chordGroup === 2) chord = [77.78, 98.00, 116.54, 155.56]; // C minor
                else chord = [58.27, 73.42, 87.31, 116.54]; // Bb minor
            }
            
            // Play chord notes!
            chord.forEach(freq => {
                try {
                    const osc = this.ctx!.createOscillator();
                    const gain = this.ctx!.createGain();
                    osc.type = isBoss ? 'sawtooth' : 'sine';
                    osc.frequency.setValueAtTime(freq, t);
                    
                    gain.gain.setValueAtTime(0, t);
                    gain.gain.linearRampToValueAtTime(isBoss ? 0.02 : 0.035, t + 0.1);
                    gain.gain.exponentialRampToValueAtTime(0.001, t + beatDuration * 7.5);
                    
                    osc.connect(gain);
                    gain.connect(SoundEffects.getDestination());
                    osc.start(t);
                    osc.stop(t + beatDuration * 8);
                } catch (e) {}
            });
        }
        
        // Gentle Arpeggiator / Percussion upbeat Click
        if (isBoss) {
            // Intense boss rhythmic beats
            let notes = [196.00, 220.00, 246.94, 293.66, 329.63, 392.00, 440.00]; // Em/G minor scales
            let noteIdx = (i * 3 + Math.floor(this.beatIndex / 16)) % notes.length;
            let freq = notes[noteIdx];
            
            // Fast ticking driving arpeggio note
            if (i % 2 === 0) {
                try {
                    const osc = this.ctx!.createOscillator();
                    const gain = this.ctx!.createGain();
                    osc.type = 'triangle';
                    osc.frequency.setValueAtTime(freq, t);
                    // rapid decay
                    gain.gain.setValueAtTime(0.015, t);
                    gain.gain.exponentialRampToValueAtTime(0.001, t + beatDuration * 0.95);
                    
                    osc.connect(gain);
                    gain.connect(SoundEffects.getDestination());
                    osc.start(t);
                    osc.stop(t + beatDuration);
                } catch (e) {}
            }
            
            // Drums / Noise Click on every 4th step!
            if (i % 4 === 2) {
                try {
                    // Generate snappier synthetic hi-hat click
                    const osc = this.ctx!.createOscillator();
                    const gain = this.ctx!.createGain();
                    osc.type = 'triangle';
                    osc.frequency.setValueAtTime(80, t);
                    osc.frequency.exponentialRampToValueAtTime(10, t + 0.05);
                    
                    gain.gain.setValueAtTime(0.02, t);
                    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.06);
                    
                    osc.connect(gain);
                    gain.connect(SoundEffects.getDestination());
                    osc.start(t);
                    osc.stop(t + 0.07);
                } catch (e) {}
            }
        } else {
            // Normal Level: ambient slow notes
            if (i % 4 === 0) {
                let caveScale = [174.61, 196.00, 207.65, 233.08, 261.63, 311.13, 349.23]; // F minor pentatonic/diatonic
                let val = caveScale[(i * 2 + Math.floor(this.beatIndex / 8)) % caveScale.length];
                try {
                    const osc = this.ctx!.createOscillator();
                    const gain = this.ctx!.createGain();
                    osc.type = 'triangle';
                    osc.frequency.setValueAtTime(val, t);
                    
                    gain.gain.setValueAtTime(0, t);
                    gain.gain.linearRampToValueAtTime(0.015, t + 0.1);
                    gain.gain.exponentialRampToValueAtTime(0.001, t + beatDuration * 3.5);
                    
                    osc.connect(gain);
                    gain.connect(SoundEffects.getDestination());
                    osc.start(t);
                    osc.stop(t + beatDuration * 4);
                } catch (e) {}
            }
        }
        
        this.beatIndex++;
        this.nextBeatTime += beatDuration;
    }

    static stopBgm() {
        this.nextBeatTime = 0;
        this.beatIndex = 0;
    }

    private static lastDevourPulse = 0;

    static playDevourPulse(prog: number) {
        if (soundMuted) return;
        let now = Date.now();
        if (now - this.lastDevourPulse < 100) return; // debounce to max 10 times per sec
        this.lastDevourPulse = now;
        
        this.init();
        if (!this.ctx) return;
        try {
            const t = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            
            osc.type = 'sine';
            let startFreq = 220 + prog * 150;
            let endFreq = 440 + prog * 440;
            osc.frequency.setValueAtTime(startFreq, t);
            osc.frequency.exponentialRampToValueAtTime(endFreq, t + 0.25);
            
            gain.gain.setValueAtTime(0.015 + prog * 0.05, t);
            gain.gain.exponentialRampToValueAtTime(0.001, t + 0.25);
            
            osc.connect(gain);
            gain.connect(SoundEffects.getDestination());
            osc.start(t);
            osc.stop(t + 0.26);
        } catch (e) {}
    }

    static playJump() {
        if (soundMuted) return;
        this.init();
        if (!this.ctx) return;
        try {
            const t = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(140, t);
            osc.frequency.exponentialRampToValueAtTime(360, t + 0.12);
            
            gain.gain.setValueAtTime(0.12, t);
            gain.gain.exponentialRampToValueAtTime(0.01, t + 0.12);
            
            osc.connect(gain);
            gain.connect(SoundEffects.getDestination());
            osc.start(t);
            osc.stop(t + 0.13);
        } catch (e) {}
    }

    static playEat() {
        if (soundMuted) return;
        this.init();
        if (!this.ctx) return;
        try {
            const t = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            
            osc.type = 'sine';
            osc.frequency.setValueAtTime(240, t);
            osc.frequency.exponentialRampToValueAtTime(100, t + 0.18);
            
            gain.gain.setValueAtTime(0.16, t);
            gain.gain.exponentialRampToValueAtTime(0.01, t + 0.18);
            
            osc.connect(gain);
            gain.connect(SoundEffects.getDestination());
            osc.start(t);
            osc.stop(t + 0.19);
        } catch (e) {}
    }

    static playShoot() {
        if (soundMuted) return;
        this.init();
        if (!this.ctx) return;
        try {
            const t = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            
            osc.type = 'sawtooth';
            osc.frequency.setValueAtTime(550, t);
            osc.frequency.exponentialRampToValueAtTime(100, t + 0.14);
            
            gain.gain.setValueAtTime(0.08, t);
            gain.gain.exponentialRampToValueAtTime(0.01, t + 0.14);
            
            osc.connect(gain);
            gain.connect(SoundEffects.getDestination());
            osc.start(t);
            osc.stop(t + 0.15);
        } catch (e) {}
    }

    static playBounce() {
        if (soundMuted) return;
        this.init();
        if (!this.ctx) return;
        try {
            const t = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(160, t);
            osc.frequency.linearRampToValueAtTime(340, t + 0.08);
            osc.frequency.exponentialRampToValueAtTime(180, t + 0.22);
            
            gain.gain.setValueAtTime(0.16, t);
            gain.gain.exponentialRampToValueAtTime(0.01, t + 0.22);
            
            osc.connect(gain);
            gain.connect(SoundEffects.getDestination());
            osc.start(t);
            osc.stop(t + 0.23);
        } catch (e) {}
    }

    static playHurt() {
        if (soundMuted) return;
        this.init();
        if (!this.ctx) return;
        try {
            const t = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            
            osc.type = 'sawtooth';
            osc.frequency.setValueAtTime(160, t);
            osc.frequency.linearRampToValueAtTime(40, t + 0.35);
            
            gain.gain.setValueAtTime(0.15, t);
            gain.gain.exponentialRampToValueAtTime(0.01, t + 0.38);
            
            osc.connect(gain);
            gain.connect(SoundEffects.getDestination());
            osc.start(t);
            osc.stop(t + 0.39);
        } catch (e) {}
    }

    static playWin() {
        if (soundMuted) return;
        this.init();
        if (!this.ctx) return;
        try {
            const t = this.ctx.currentTime;
            const notes = [261.63, 329.63, 392.00, 523.25, 659.25, 783.99, 1046.50];
            notes.forEach((freq, idx) => {
                if (!this.ctx) return;
                const noteTime = t + idx * 0.08;
                const osc = this.ctx.createOscillator();
                const gain = this.ctx.createGain();
                
                osc.type = 'triangle';
                osc.frequency.setValueAtTime(freq, noteTime);
                
                gain.gain.setValueAtTime(0.08, noteTime);
                gain.gain.exponentialRampToValueAtTime(0.01, noteTime + 0.18);
                
                osc.connect(gain);
                gain.connect(SoundEffects.getDestination());
                osc.start(noteTime);
                osc.stop(noteTime + 0.2);
            });
        } catch (e) {}
    }

    static playLand() {
        if (soundMuted) return;
        this.init();
        if (!this.ctx) return;
        try {
            const t = this.ctx.currentTime;
            const osc = this.ctx.createOscillator();
            const gain = this.ctx.createGain();
            
            osc.type = 'sine';
            osc.frequency.setValueAtTime(95, t);
            osc.frequency.exponentialRampToValueAtTime(45, t + 0.08);
            
            gain.gain.setValueAtTime(0.08, t);
            gain.gain.exponentialRampToValueAtTime(0.01, t + 0.08);
            
            osc.connect(gain);
            gain.connect(SoundEffects.getDestination());
            osc.start(t);
            osc.stop(t + 0.09);
        } catch (e) {}
    }
}
