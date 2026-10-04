//! Hand-written WGSL port of the SDK shaders.
//!
//! `shaders/wgsl/` mirrors `sdk/include/FidelityFX/gpu/` (one module per SDK
//! header) and `sdk/src/backends/dx12/shaders/` (one entry module per pass).
//! WGSL has no preprocessor, so a pass is assembled here from its entry module
//! by resolving the same `#include`, `#define`, `#if`/`#ifdef`/`#ifndef`/`#elif`,
//! `#else` and `#endif` lines the SDK uses; the permutation prelude supplies the
//! SDK's compile defines. There is no text substitution: `#define NAME VALUE`
//! becomes `const NAME = VALUE;`, whose abstract type, like DXC's untyped
//! literals, follows the operand it combines with. An `FFX_UNROLL` line, the
//! SDK's `[unroll]`, unrolls the `for` statement after it (`unroll`).
use crate::types::FfxShaderBlob;
use std::collections::HashMap;

macro_rules! modules {
    ($($path:literal),* $(,)?) => {
        &[$(($path, include_str!(concat!("../shaders/wgsl/", $path)))),*]
    };
}

/// Retained WGSL modules, by path relative to `shaders/wgsl/`.
const MODULES: &[(&str, &str)] = modules![
    "ffx_core.wgsl",
    "spd/ffx_spd.wgsl",
    "fsr1/ffx_fsr1.wgsl",
    "fsr2/ffx_fsr2_resources.wgsl",
    "fsr2/ffx_fsr2_callbacks.wgsl",
    "fsr2/ffx_fsr2_common.wgsl",
    "fsr2/ffx_fsr2_sample.wgsl",
    "fsr2/ffx_fsr2_rcas.wgsl",
    "fsr2/ffx_fsr2_rcas_pass.wgsl",
    "fsr2/ffx_fsr2_upsample.wgsl",
    "fsr2/ffx_fsr2_postprocess_lock_status.wgsl",
    "fsr2/ffx_fsr2_reproject.wgsl",
    "fsr2/ffx_fsr2_accumulate.wgsl",
    "fsr2/ffx_fsr2_accumulate_pass.wgsl",
    "fsr2/ffx_fsr2_reconstruct_dilated_velocity_and_previous_depth.wgsl",
    "fsr2/ffx_fsr2_reconstruct_previous_depth_pass.wgsl",
    "fsr2/ffx_fsr2_depth_clip.wgsl",
    "fsr2/ffx_fsr2_depth_clip_pass.wgsl",
    "fsr2/ffx_fsr2_lock.wgsl",
    "fsr2/ffx_fsr2_lock_pass.wgsl",
    "fsr2/ffx_fsr2_compute_luminance_pyramid.wgsl",
    "fsr2/ffx_fsr2_compute_luminance_pyramid_pass.wgsl",
    "fsr2/ffx_fsr2_autogen_reactive_pass.wgsl",
    "fsr2/ffx_fsr2_tcr_autogen.wgsl",
    "fsr2/ffx_fsr2_tcr_autogen_pass.wgsl",
];

/// The compile defines an effect's SDK shader build gives every pass and
/// permutation, by pass shader-name prefix: FSR2's `FSR2_BASE_ARGS`
/// (`gpu/fsr2/CMakeCompileFSR2Shaders.txt`).
const EFFECT_DEFINES: &[(&str, &[(&str, &str)])] = &[(
    "ffx_fsr2_",
    &[
        ("FFX_FSR2_OPTION_UPSAMPLE_SAMPLERS_USE_DATA_HALF", "0"),
        ("FFX_FSR2_OPTION_ACCUMULATE_SAMPLERS_USE_DATA_HALF", "0"),
        ("FFX_FSR2_OPTION_REPROJECT_SAMPLERS_USE_DATA_HALF", "1"),
        (
            "FFX_FSR2_OPTION_POSTPROCESSLOCKSTATUS_SAMPLERS_USE_DATA_HALF",
            "0",
        ),
        ("FFX_FSR2_OPTION_UPSAMPLE_USE_LANCZOS_TYPE", "2"),
    ],
)];

/// WGSL binding offsets of the HLSL register classes: the pass modules declare
/// `tN`, `uN`, `bN` and `sN` at `N`, `64 + N`, `128 + N` and `192 + N` of
/// group 0. Each class has 64 registers: FSR2's descriptor tables hold
/// `FFX_FSR2_RESOURCE_IDENTIFIER_COUNT` (58) SRVs and UAVs
/// (`ffx_fsr2_callbacks_hlsl.h:175-176`), and its TCR pass declares `t46` and
/// `t47` (`:417`, `:420`).
pub const FFX_WGSL_BINDING_OFFSET_SRV: u32 = 0;
pub const FFX_WGSL_BINDING_OFFSET_UAV: u32 = 64;
pub const FFX_WGSL_BINDING_OFFSET_CBV: u32 = 128;
pub const FFX_WGSL_BINDING_OFFSET_SAMPLER: u32 = 192;

/// The WGSL entry point of every pass module (the SDK's `CS`).
pub const FFX_WGSL_ENTRY_POINT: &str = "CS";

/// WGSL source for a blob: the stand-in for the SDK blob's DXIL/SPIR-V
/// bytecode. `None` for the empty blob or a pass this crate does not port.
///
/// The pass entry module is `<shader_name>.wgsl`. The effect's build defines
/// (`EFFECT_DEFINES`) and the blob's permutation supply the SDK's compile
/// defines: `fp16` (`ALLOW_FP16`) selects `FFX_HALF`, and each
/// `PermutationKey` bit its `FFX_<EFFECT>_OPTION_*`. The source begins with
/// the binding offsets as WGSL constants of the same names.
/// `FORCE_WAVE64` "doesn't map to a define, selects different table"; WGSL
/// cannot request a subgroup size, so both tables share one source and a
/// backend must not select a wave64 blob (SDK-P6).
pub fn ffx_get_wgsl_source(blob: &FfxShaderBlob) -> Option<String> {
    let file = format!("{}.wgsl", blob.shader_name);
    let (module, _) = MODULES
        .iter()
        .find(|(path, _)| path.rsplit('/').next() == Some(file.as_str()))?;
    let permutation = blob.permutation;
    let mut preprocessor = Preprocessor {
        defines: HashMap::from([
            ("FFX_GPU".to_owned(), "1".to_owned()),
            ("FFX_WGSL".to_owned(), "1".to_owned()),
            (
                "FFX_HALF".to_owned(),
                u8::from(permutation.fp16).to_string(),
            ),
        ]),
        output: String::new(),
    };
    for (prefix, defines) in EFFECT_DEFINES {
        if blob.shader_name.starts_with(prefix) {
            for (name, value) in *defines {
                preprocessor
                    .defines
                    .insert((*name).to_owned(), (*value).to_owned());
            }
        }
    }
    for (bit, option) in permutation.key_options.iter().enumerate() {
        let value = (permutation.key_index >> bit) & 1;
        preprocessor
            .defines
            .insert((*option).to_owned(), value.to_string());
    }
    if permutation.fp16 {
        preprocessor.output.push_str("enable f16;\n");
    }
    for (name, offset) in [
        ("FFX_WGSL_BINDING_OFFSET_SRV", FFX_WGSL_BINDING_OFFSET_SRV),
        ("FFX_WGSL_BINDING_OFFSET_UAV", FFX_WGSL_BINDING_OFFSET_UAV),
        ("FFX_WGSL_BINDING_OFFSET_CBV", FFX_WGSL_BINDING_OFFSET_CBV),
        (
            "FFX_WGSL_BINDING_OFFSET_SAMPLER",
            FFX_WGSL_BINDING_OFFSET_SAMPLER,
        ),
    ] {
        preprocessor
            .output
            .push_str(&format!("const {name} = {offset}u;\n"));
    }
    preprocessor.include(module);
    Some(unroll(preprocessor.output))
}

/// The SDK's `FFX_UNROLL` (`[unroll]`, `ffx_core_hlsl.h:91`), which WGSL
/// cannot express: the `for` statement after an `FFX_UNROLL` line becomes one
/// block per iteration, in order, each binding the loop variable to that
/// iteration's value; the variable of an initializing assignment ends with
/// its exit value. As with `[unroll]`, the trip count must be a compile-time
/// constant: the loop is `for (var i = A; i < B; i++)` (or `i <= B`, or
/// `i = A` for an outer variable) with integer literals or constants for `A`
/// and `B`, and its body neither breaks nor continues it nor assigns `i`.
/// Unrolling keeps every operation and its order.
///
/// Naga emits each WGSL loop for Metal as a bounded `while (true)`, which the
/// Metal compiler does not unroll (CONFORMANCE.md, SDK-P26).
fn unroll(mut source: String) -> String {
    while let Some(marker) = source
        .match_indices("FFX_UNROLL")
        .map(|(at, _)| at)
        .find(|&at| {
            let line_start = source[..at].rfind('\n').map_or(0, |n| n + 1);
            let line_end = source[at..].find('\n').map_or(source.len(), |n| at + n);
            source[line_start..line_end].trim() == "FFX_UNROLL"
        })
    {
        let line_start = source[..marker].rfind('\n').map_or(0, |n| n + 1);
        let statement = marker + "FFX_UNROLL".len();
        let (unrolled, end) = unroll_for(&source, statement);
        source.replace_range(line_start..end, &unrolled);
    }
    source
}

/// The unrolled `for` statement that follows `at` (after whitespace and
/// comments), and the end of the statement.
fn unroll_for(source: &str, at: usize) -> (String, usize) {
    let fail = |what: &str| -> ! {
        let line = source[..at].lines().count();
        panic!("FFX_UNROLL at preprocessed line {line}: {what}")
    };
    let for_at = skip_trivia(source, at);
    if !source[for_at..].starts_with("for") {
        fail("not followed by a for statement");
    }
    let open = skip_trivia(source, for_at + 3);
    if source.as_bytes()[open] != b'(' {
        fail("malformed for statement");
    }
    let close = matching(source, open);
    let body_open = skip_trivia(source, close + 1);
    if source.as_bytes()[body_open] != b'{' {
        fail("for statement without a braced body");
    }
    let body_close = matching(source, body_open);
    let body = &source[body_open + 1..body_close];

    let header: Vec<&str> = source[open + 1..close].split(';').map(str::trim).collect();
    let [init, condition, update] = header[..] else {
        fail("for statement without three clauses");
    };
    let (declared, init) = init
        .strip_prefix("var ")
        .map_or((false, init), |rest| (true, rest.trim()));
    let (target, first) = init
        .split_once('=')
        .unwrap_or_else(|| fail("the loop variable is not initialized"));
    let (name, ty) = target
        .split_once(':')
        .map_or((target.trim(), None), |(n, t)| (n.trim(), Some(t.trim())));
    let first = integer(source, at, first).unwrap_or_else(|| fail("non-constant start"));
    let (inclusive, bound) = if let Some(bound) = condition.strip_prefix(&format!("{name} <=")) {
        (true, bound)
    } else if let Some(bound) = condition.strip_prefix(&format!("{name} <")) {
        (false, bound)
    } else {
        fail("condition is not the loop variable < or <= a bound");
    };
    let bound = integer(source, at, bound).unwrap_or_else(|| fail("non-constant bound"));
    let end = if inclusive { bound + 1 } else { bound };
    if update != format!("{name}++") {
        fail("update is not an increment of the loop variable");
    }
    let body_code = strip_comments(body);
    if tokenize(&body_code)
        .iter()
        .any(|t| t == "break" || t == "continue")
    {
        fail("the body breaks or continues the loop");
    }
    if assigns(&body_code, name) {
        fail("the body assigns the loop variable or takes its address");
    }

    let mut unrolled = format!(
        "{{ // FFX_UNROLL: for ({})\n",
        source[open + 1..close].trim()
    );
    for value in first..end {
        let binding = match (declared, ty) {
            (true, Some(ty)) => format!("let {name}: {ty} = {value};"),
            (true, None) => format!("let {name} = {value};"),
            (false, _) => format!("{name} = {value};"),
        };
        unrolled.push_str(&format!("{{ {binding}{body}}}\n"));
    }
    if !declared {
        unrolled.push_str(&format!("{name} = {};\n", end.max(first)));
    }
    unrolled.push('}');
    (unrolled, body_close + 1)
}

/// The position of the first character after whitespace and comments.
fn skip_trivia(source: &str, mut at: usize) -> usize {
    loop {
        let rest = &source[at..];
        let trimmed = rest.trim_start();
        at += rest.len() - trimmed.len();
        if trimmed.starts_with("//") {
            at += trimmed.find('\n').unwrap_or(trimmed.len());
        } else if trimmed.starts_with("/*") {
            at += trimmed.find("*/").expect("unterminated comment") + 2;
        } else {
            return at;
        }
    }
}

/// The position of the bracket closing the one at `open`, past comments.
fn matching(source: &str, open: usize) -> usize {
    let bytes = source.as_bytes();
    let (opening, closing) = (bytes[open], if bytes[open] == b'(' { b')' } else { b'}' });
    let mut depth = 0;
    let mut at = open;
    loop {
        if source[at..].starts_with("//") || source[at..].starts_with("/*") {
            at = skip_trivia(source, at);
            continue;
        }
        if bytes[at] == opening {
            depth += 1;
        } else if bytes[at] == closing {
            depth -= 1;
            if depth == 0 {
                return at;
            }
        }
        at += 1;
    }
}

fn strip_comments(text: &str) -> String {
    let mut out = String::new();
    let mut at = 0;
    while at < text.len() {
        let next = skip_trivia(text, at);
        if next > at {
            out.push(' ');
            at = next;
            continue;
        }
        let c = text[at..].chars().next().unwrap();
        out.push(c);
        at += c.len_utf8();
    }
    out
}

/// A constant integer expression at `at`: integer literals, the C operators
/// and the `const` or `let` integers in scope (the enclosing function's latest
/// declaration before `at`, else the module's); `None` otherwise.
fn integer(source: &str, at: usize, expression: &str) -> Option<i64> {
    let mut expanded = Vec::new();
    for token in tokenize(expression) {
        if token.starts_with(|c: char| c.is_ascii_digit()) {
            let digits = token.trim_end_matches(['i', 'u']);
            digits.parse::<i64>().ok()?;
            expanded.push(digits.to_owned());
        } else if token.starts_with(|c: char| c.is_ascii_alphabetic() || c == '_') {
            let value = constant(source, at, &token)?;
            expanded.extend(tokenize(&value.to_string()));
        } else if binary_precedence(&token).is_some()
            || ["(", ")", "!", "~"].contains(&token.as_str())
        {
            expanded.push(token);
        } else {
            return None;
        }
    }
    let mut position = 0;
    let value = parse_expression(&expanded, &mut position, 0);
    (position == expanded.len()).then_some(value)
}

fn constant(source: &str, at: usize, name: &str) -> Option<i64> {
    // `const NAME ... = VALUE;` or `let NAME ... = VALUE;` on one line; an
    // initializer over several lines is not a constant here.
    fn declared<'a>(line: &'a str, name: &str) -> Option<Option<&'a str>> {
        let line = line.trim_start();
        let rest = line
            .strip_prefix("const ")
            .or_else(|| line.strip_prefix("let "))?;
        let (target, value) = rest.split_once('=')?;
        (target.split(':').next()?.trim() == name)
            .then(|| value.trim().strip_suffix(';').map(str::trim))
    }
    let declaration = |line| declared(line, name);
    let function = source[..at].rfind("\nfn ").map_or(0, |n| n + 1);
    if function > 0 {
        // A parameter of the enclosing function shadows constants.
        let signature = &source[function..function + source[function..].find('{')?];
        if tokenize(signature)
            .windows(2)
            .any(|w| w[0] == name && w[1] == ":")
        {
            return None;
        }
    }
    let mut found = None;
    let mut offset = function;
    for line in source[function..at].split_inclusive('\n') {
        if let Some(value) = declaration(line) {
            found = Some((value?, offset));
        }
        offset += line.len();
    }
    if found.is_none() {
        offset = 0;
        for line in source.split_inclusive('\n') {
            if !line.starts_with(char::is_whitespace)
                && let Some(value) = declaration(line)
            {
                if found.is_some() {
                    return None;
                }
                found = Some((value?, offset));
            }
            offset += line.len();
        }
    }
    let (value, position) = found?;
    integer(source, position, value)
}

/// Whether `code` assigns `name` (`=`, a compound assignment, `++`, `--`) or
/// takes its address.
fn assigns(code: &str, name: &str) -> bool {
    code.match_indices(name).any(|(at, _)| {
        let word = |c: char| c.is_ascii_alphanumeric() || c == '_';
        let before = code[..at].trim_end();
        let after = code[at + name.len()..].trim_start();
        if code[..at].ends_with(word) || code[at + name.len()..].starts_with(word) {
            return false;
        }
        (before.ends_with('&') && !before.ends_with("&&"))
            || after.starts_with("++")
            || after.starts_with("--")
            || (after.starts_with('=') && !after.starts_with("=="))
            || ["+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>="]
                .iter()
                .any(|op| after.starts_with(op))
    })
}

/// The subset of the C preprocessor the retained modules use.
struct Preprocessor {
    defines: HashMap<String, String>,
    output: String,
}

struct Conditional {
    parent_active: bool,
    active: bool,
    taken: bool,
}

impl Preprocessor {
    fn include(&mut self, path: &str) {
        let source = MODULES
            .iter()
            .find(|(name, _)| *name == path)
            .unwrap_or_else(|| panic!("unknown WGSL module {path}"))
            .1;
        let mut stack: Vec<Conditional> = Vec::new();
        for line in source.lines() {
            let active = stack.last().is_none_or(|c| c.active);
            let Some(directive) = line.trim_start().strip_prefix('#') else {
                if active {
                    self.output.push_str(line);
                    self.output.push('\n');
                }
                continue;
            };
            let directive = strip_comment(directive).trim();
            let (name, rest) = directive
                .split_once(char::is_whitespace)
                .map_or((directive, ""), |(n, r)| (n, r.trim()));
            match name {
                "if" | "ifdef" | "ifndef" => {
                    let value = active
                        && match name {
                            "if" => self.evaluate(rest) != 0,
                            "ifdef" => self.defines.contains_key(rest),
                            _ => !self.defines.contains_key(rest),
                        };
                    stack.push(Conditional {
                        parent_active: active,
                        active: value,
                        taken: value,
                    });
                }
                "elif" => {
                    let top = stack.last().expect("#elif without #if");
                    let value = top.parent_active && !top.taken && self.evaluate(rest) != 0;
                    let top = stack.last_mut().unwrap();
                    top.active = value;
                    top.taken |= value;
                }
                "else" => {
                    let top = stack.last_mut().expect("#else without #if");
                    top.active = top.parent_active && !top.taken;
                    top.taken = true;
                }
                "endif" => {
                    stack.pop().expect("#endif without #if");
                }
                _ if !active => {}
                "define" => {
                    let (name, value) = rest
                        .split_once(char::is_whitespace)
                        .map_or((rest, ""), |(n, v)| (n, v.trim()));
                    if !value.is_empty() {
                        self.output.push_str(&format!("const {name} = {value};\n"));
                    }
                    self.defines.insert(name.to_owned(), value.to_owned());
                }
                "include" => self.include(rest.trim_matches('"')),
                _ => panic!("unsupported directive #{name} in {path}"),
            }
        }
        assert!(stack.is_empty(), "unterminated #if in {path}");
    }

    /// Integer `#if` expression: `defined(NAME)`, defines, literals and the C
    /// operators; an undefined name is 0.
    fn evaluate(&self, condition: &str) -> i64 {
        let tokens = tokenize(condition);
        let mut expanded = Vec::new();
        let mut i = 0;
        while i < tokens.len() {
            if tokens[i] == "defined" {
                let parenthesized = tokens.get(i + 1).is_some_and(|t| t == "(");
                let name = &tokens[i + if parenthesized { 2 } else { 1 }];
                expanded.push(u8::from(self.defines.contains_key(name)).to_string());
                i += if parenthesized { 4 } else { 2 };
            } else {
                let value = self.defines.get(&tokens[i]).filter(|v| !v.is_empty());
                expanded.extend(value.map_or_else(|| vec![tokens[i].clone()], |v| tokenize(v)));
                i += 1;
            }
        }
        let mut position = 0;
        let value = parse_expression(&expanded, &mut position, 0);
        assert_eq!(
            position,
            expanded.len(),
            "trailing tokens in #if {condition}"
        );
        value
    }
}

fn strip_comment(line: &str) -> &str {
    line.find("//").map_or(line, |at| &line[..at])
}

fn tokenize(text: &str) -> Vec<String> {
    let mut tokens = Vec::new();
    let chars: Vec<char> = text.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        let c = chars[i];
        if c.is_whitespace() {
            i += 1;
        } else if c.is_ascii_alphanumeric() || c == '_' {
            let start = i;
            while i < chars.len() && (chars[i].is_ascii_alphanumeric() || chars[i] == '_') {
                i += 1;
            }
            tokens.push(chars[start..i].iter().collect());
        } else {
            let pair: String = chars[i..(i + 2).min(chars.len())].iter().collect();
            if ["&&", "||", "==", "!=", "<=", ">=", "<<", ">>"].contains(&pair.as_str()) {
                tokens.push(pair);
                i += 2;
            } else {
                tokens.push(c.to_string());
                i += 1;
            }
        }
    }
    tokens
}

fn binary_precedence(operator: &str) -> Option<u8> {
    Some(match operator {
        "||" => 1,
        "&&" => 2,
        "|" => 3,
        "^" => 4,
        "&" => 5,
        "==" | "!=" => 6,
        "<" | "<=" | ">" | ">=" => 7,
        "<<" | ">>" => 8,
        "+" | "-" => 9,
        "*" | "/" | "%" => 10,
        _ => return None,
    })
}

fn parse_expression(tokens: &[String], position: &mut usize, min_precedence: u8) -> i64 {
    let mut left = parse_unary(tokens, position);
    while let Some(operator) = tokens.get(*position) {
        let Some(precedence) = binary_precedence(operator).filter(|p| *p > min_precedence) else {
            break;
        };
        let operator = operator.clone();
        *position += 1;
        let right = parse_expression(tokens, position, precedence);
        left = match operator.as_str() {
            "||" => i64::from(left != 0 || right != 0),
            "&&" => i64::from(left != 0 && right != 0),
            "|" => left | right,
            "^" => left ^ right,
            "&" => left & right,
            "==" => i64::from(left == right),
            "!=" => i64::from(left != right),
            "<" => i64::from(left < right),
            "<=" => i64::from(left <= right),
            ">" => i64::from(left > right),
            ">=" => i64::from(left >= right),
            "<<" => left << right,
            ">>" => left >> right,
            "+" => left + right,
            "-" => left - right,
            "*" => left * right,
            "/" => left / right,
            _ => left % right,
        };
    }
    left
}

fn parse_unary(tokens: &[String], position: &mut usize) -> i64 {
    let token = tokens
        .get(*position)
        .expect("incomplete #if expression")
        .clone();
    *position += 1;
    match token.as_str() {
        "!" => i64::from(parse_unary(tokens, position) == 0),
        "-" => -parse_unary(tokens, position),
        "~" => !parse_unary(tokens, position),
        "(" => {
            let value = parse_expression(tokens, position, 0);
            assert_eq!(tokens.get(*position).map(String::as_str), Some(")"));
            *position += 1;
            value
        }
        _ if token.starts_with(|c: char| c.is_ascii_digit()) => token
            .trim_end_matches(['u', 'U', 'l', 'L'])
            .parse()
            .expect("integer in #if"),
        // Identifiers that are not macros evaluate to zero.
        _ => 0,
    }
}
