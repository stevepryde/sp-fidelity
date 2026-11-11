# Frame interpolation presentation contract

The native wgpu backend ports AMD SDK 1.1.4's frame-interpolation swapchain
behavior. The reference is the unchanged DX12/Vulkan presentation code at
the revision in `crates/sp-fidelity/vendor/sdk-1.1.4/source-revision.txt`.
The consumer owns its window and event loop and supplies its surface.

1. Generation uses the SDK callback or a caller-recorded interpolation
   command list. Generated output precedes real output; configuration includes
   interpolation-only presentation, frame identity, reset, interpolation rect,
   transfer function and luminance. A failed generation must not present
   unwritten output.
2. Presentation uses AMD's ten-sample completion-time estimator, warmup,
   timeout reset, variance adjustment and safety margin. Completion observation
   and paced presentation run independently. Timing follows GPU completion and
   the previous actual presentation call, not encoder creation or ideal deadlines.
3. Default composition copies unmodified color when no UI is registered. With
   UI it uses AMD's integer texel loads and straight/premultiplied alpha formulas.
   Custom callbacks and debug pacing indicators are supported. UI composition
   also runs while generation is disabled: default composition writes directly
   to an acquired surface in the caller submission, without worker scheduling.
4. SDK contexts and callbacks stay on their creating thread. Owned prepared
   textures cross to workers; transient SDK handles never do. Source reads are
   submitted before returning source ownership to the consumer. Pending work
   and retained output allocations are bounded and slots are not reused before
   the presentation worker has submitted its reads on the shared queue. Queue
   ordering protects subsequent reuse; explicit drains wait for GPU completion.
5. Configuration changes that affect callbacks or generation, resize, and
   shutdown drain pending work. Surface acquisition and device errors retire
   work and reach the consumer. Shutdown joins workers, including error paths.
   Waiting for presents means GPU work and presentation calls, not scanout.
6. The backend supplies surface presentation and a target boundary for testing
   and external presentation integration. It adds no window or event loop to
   the runtime. WASM continues to compile; native threaded presentation is
   explicitly unavailable there.
7. wgpu's single queue replaces AMD's explicit queue and semaphore topology.
   Composition uses AMD's game-queue mode because Rust SDK callbacks are
   thread-confined. Native swapchain interception, queue priorities, OS latency
   handles and scanout fences are not emulated. Differences belong in
   `CONFORMANCE.md`; neither documentation nor tests may claim native-API parity.

Acceptance: compare pacing traces with compiled unchanged AMD source; compare
GPU composition with independent expected pixels and retained source; exercise
worker ordering, source reuse, generation failure, mode changes, resize and
shutdown at their real boundaries; run a windowed native example and the
repository's required checks. Review the stable implementation independently.
