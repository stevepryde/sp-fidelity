//! Port of AMD's `SimpleMovingAverage` and `interpolationThread` pacing math.
//! Copyright (C) 2024 Advanced Micro Devices, Inc. MIT; see LICENSE.txt.

/// SDK frame-pacing controls. Time is in milliseconds; the estimator internally
/// uses performance-counter ticks, as AMD's implementation does.
#[derive(Clone, Copy, Debug)]
pub struct FramePacingTuning {
    pub safety_margin_ms: f32,
    pub variance_factor: f32,
    /// Permit sleeping before the final spin. Rust cannot request an OS timer
    /// resolution; the native adaptation leaves this many milliseconds to spin.
    pub allow_hybrid_spin: bool,
    pub hybrid_spin_ms: u32,
}

impl Default for FramePacingTuning {
    fn default() -> Self {
        Self {
            safety_margin_ms: 0.1,
            variance_factor: 0.1,
            allow_hybrid_spin: false,
            hybrid_spin_ms: 2,
        }
    }
}

/// AMD's ten-sample estimator. Exposed for the independent C++ oracle and for
/// integrations supplying their own performance counter. `sample` is called
/// after interpolation completes, never when CPU encoding starts.
pub struct FramePacing {
    frequency: i64,
    previous: i64,
    history: [f64; 10],
    index: usize,
    count: u32,
}

impl FramePacing {
    pub fn new(frequency: i64) -> Self {
        Self {
            frequency,
            previous: 0,
            history: [0.; 10],
            index: 0,
            count: 0,
        }
    }

    /// Return the interval before *each* generated/real presentation, in ticks.
    pub fn sample(&mut self, completed: i64, reset: bool, tuning: FramePacingTuning) -> i64 {
        let delta = (completed - self.previous) as f64 * f64::from(self.previous > 0);
        self.previous = completed;
        // C++ converts the integer frequency to float and multiplies in float
        // before promoting the threshold to double. Preserve both roundings.
        if delta > f64::from(self.frequency as f32 * 0.1f32) || reset {
            self.count = 0;
            self.index = 0;
        } else {
            self.history[self.index] = delta;
            self.index = (self.index + 1) % 10;
            self.count = self.count.wrapping_add(1);
        }
        let (average, variance) = if self.count < 10 {
            (0., 0.)
        } else {
            let average = self.history.iter().sum::<f64>() / 10.;
            let variance = (self
                .history
                .iter()
                .map(|x| (x - average) * (x - average))
                .sum::<f64>()
                / 10.)
                .sqrt();
            (average, variance)
        };
        let margin = (self.frequency as f64 * (f64::from(tuning.safety_margin_ms) / 1000.)) as i64;
        let conservative = (average * 0.5 - variance * f64::from(tuning.variance_factor)) as i64;
        if conservative > margin {
            conservative - margin
        } else {
            0
        }
    }
}
