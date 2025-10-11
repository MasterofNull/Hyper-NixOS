// auto-generated: "lalrpop 0.20.2"
// sha3: f86f2166b3c1902386b703da5f3fe3c861c78783012d2a82fb8db72a5a675e4d
use std::convert::TryInto;
use std::sync::Arc;
use crate::Error;
use crate::packet::Any;
use crate::packet::Signature;
use crate::packet::UserID;
use crate::packet::UserAttribute;
use crate::packet::{key, Key};
use crate::packet::Unknown;
use crate::Packet;
use crate::policy::HashAlgoSecurity::CollisionResistance;
use crate::cert::prelude::*;
use crate::cert::parser::low_level::lexer;
use crate::cert::parser::low_level::lexer::{Token, Component};
use crate::cert::parser::low_level::grammar_util::*;
use crate::cert::ComponentBundles;
use crate::cert::parser::low_level::bundle::{
    PrimaryKeyBundle,
    SubkeyBundle,
    UserIDBundle,
    UserAttributeBundle,
    UnknownBundle,
};
use lalrpop_util::ParseError;
#[allow(unused_extern_crates)]
extern crate lalrpop_util as __lalrpop_util;
#[allow(unused_imports)]
use self::__lalrpop_util::state_machine as __state_machine;
extern crate core;
extern crate alloc;

#[rustfmt::skip]
#[allow(non_snake_case, non_camel_case_types, unused_mut, unused_variables, unused_imports, unused_parens, clippy::needless_lifetimes, clippy::type_complexity, clippy::needless_return, clippy::too_many_arguments, clippy::never_loop, clippy::match_single_binding, clippy::needless_raw_string_hashes)]
mod __parse__Cert {

    use std::convert::TryInto;
    use std::sync::Arc;
    use crate::Error;
    use crate::packet::Any;
    use crate::packet::Signature;
    use crate::packet::UserID;
    use crate::packet::UserAttribute;
    use crate::packet::{key, Key};
    use crate::packet::Unknown;
    use crate::Packet;
    use crate::policy::HashAlgoSecurity::CollisionResistance;
    use crate::cert::prelude::*;
    use crate::cert::parser::low_level::lexer;
    use crate::cert::parser::low_level::lexer::{Token, Component};
    use crate::cert::parser::low_level::grammar_util::*;
    use crate::cert::ComponentBundles;
    use crate::cert::parser::low_level::bundle::{
    PrimaryKeyBundle,
    SubkeyBundle,
    UserIDBundle,
    UserAttributeBundle,
    UnknownBundle,
};
    use lalrpop_util::ParseError;
    #[allow(unused_extern_crates)]
    extern crate lalrpop_util as __lalrpop_util;
    #[allow(unused_imports)]
    use self::__lalrpop_util::state_machine as __state_machine;
    extern crate core;
    extern crate alloc;
    use super::__ToTriple;
    #[allow(dead_code)]
    pub(crate) enum __Symbol<>
     {
        Variant0(lexer::Token),
        Variant1(Option<Cert>),
        Variant2(Option<Component>),
        Variant3(Option<Vec<Component>>),
        Variant4(Option<Vec<Signature>>),
        Variant5(Option<(Packet, Vec<Signature>)>),
        Variant6(Option<Packet>),
        Variant7(Option<PacketOrUnknown<Key<key::PublicParts, key::SubordinateRole>>>),
        Variant8(Option<Unknown>),
        Variant9(Option<PacketOrUnknown<UserAttribute>>),
        Variant10(Option<PacketOrUnknown<UserID>>),
    }
    const __ACTION: &[i8] = &[
        // State 0
        10, 0, 11, 0, 0, 0, 0, 0, 0,
        // State 1
        0, -6, 0, -6, 0, 0, -6, -6, -6,
        // State 2
        0, -8, 0, -8, -8, -8, -8, -8, -8,
        // State 3
        0, 14, 0, 15, 0, 0, 16, 17, 18,
        // State 4
        0, -8, 0, -8, -8, -8, -8, -8, -8,
        // State 5
        0, -8, 0, -8, -8, -8, -8, -8, -8,
        // State 6
        0, -8, 0, -8, -8, -8, -8, -8, -8,
        // State 7
        0, -8, 0, -8, -8, -8, -8, -8, -8,
        // State 8
        0, 0, 0, 0, 0, 0, 0, 0, 0,
        // State 9
        0, -12, 0, -12, -12, -12, -12, -12, -12,
        // State 10
        0, -13, 0, -13, -13, -13, -13, -13, -13,
        // State 11
        0, -11, 0, -11, 19, 20, -11, -11, -11,
        // State 12
        0, -7, 0, -7, 0, 0, -7, -7, -7,
        // State 13
        0, -14, 0, -14, -14, -14, -14, -14, -14,
        // State 14
        0, -15, 0, -15, -15, -15, -15, -15, -15,
        // State 15
        0, -16, 0, -16, -16, -16, -16, -16, -16,
        // State 16
        0, -18, 0, -18, -18, -18, -18, -18, -18,
        // State 17
        0, -17, 0, -17, -17, -17, -17, -17, -17,
        // State 18
        0, -9, 0, -9, -9, -9, -9, -9, -9,
        // State 19
        0, -10, 0, -10, -10, -10, -10, -10, -10,
        // State 20
        0, -2, 0, -2, 19, 20, -2, -2, -2,
        // State 21
        0, -5, 0, -5, 19, 20, -5, -5, -5,
        // State 22
        0, -4, 0, -4, 19, 20, -4, -4, -4,
        // State 23
        0, -3, 0, -3, 19, 20, -3, -3, -3,
    ];
    fn __action(state: i8, integer: usize) -> i8 {
        __ACTION[(state as usize) * 9 + integer]
    }
    const __EOF_ACTION: &[i8] = &[
        // State 0
        0,
        // State 1
        -6,
        // State 2
        -8,
        // State 3
        -1,
        // State 4
        -8,
        // State 5
        -8,
        // State 6
        -8,
        // State 7
        -8,
        // State 8
        -19,
        // State 9
        -12,
        // State 10
        -13,
        // State 11
        -11,
        // State 12
        -7,
        // State 13
        -14,
        // State 14
        -15,
        // State 15
        -16,
        // State 16
        -18,
        // State 17
        -17,
        // State 18
        -9,
        // State 19
        -10,
        // State 20
        -2,
        // State 21
        -5,
        // State 22
        -4,
        // State 23
        -3,
    ];
    fn __goto(state: i8, nt: usize) -> i8 {
        match nt {
            0 => 8,
            1 => 12,
            2 => 3,
            3 => match state {
                4 => 20,
                5 => 21,
                6 => 22,
                7 => 23,
                _ => 11,
            },
            4 => 1,
            5 => 2,
            6 => 4,
            7 => 5,
            8 => 6,
            9 => 7,
            _ => 0,
        }
    }
    const __TERMINAL: &[&str] = &[
        r###"PUBLIC_KEY"###,
        r###"PUBLIC_SUBKEY"###,
        r###"SECRET_KEY"###,
        r###"SECRET_SUBKEY"###,
        r###"SIGNATURE"###,
        r###"TRUST"###,
        r###"UNKNOWN"###,
        r###"USERID"###,
        r###"USER_ATTRIBUTE"###,
    ];
    fn __expected_tokens(__state: i8) -> alloc::vec::Vec<alloc::string::String> {
        __TERMINAL.iter().enumerate().filter_map(|(index, terminal)| {
            let next_state = __action(__state, index);
            if next_state == 0 {
                None
            } else {
                Some(alloc::string::ToString::to_string(terminal))
            }
        }).collect()
    }
    fn __expected_tokens_from_states<
    >(
        __states: &[i8],
        _: core::marker::PhantomData<()>,
    ) -> alloc::vec::Vec<alloc::string::String>
    {
        __TERMINAL.iter().enumerate().filter_map(|(index, terminal)| {
            if __accepts(None, __states, Some(index), core::marker::PhantomData::<()>) {
                Some(alloc::string::ToString::to_string(terminal))
            } else {
                None
            }
        }).collect()
    }
    struct __StateMachine<>
    where 
    {
        __phantom: core::marker::PhantomData<()>,
    }
    impl<> __state_machine::ParserDefinition for __StateMachine<>
    where 
    {
        type Location = usize;
        type Error = Error;
        type Token = lexer::Token;
        type TokenIndex = usize;
        type Symbol = __Symbol<>;
        type Success = Option<Cert>;
        type StateIndex = i8;
        type Action = i8;
        type ReduceIndex = i8;
        type NonterminalIndex = usize;

        #[inline]
        fn start_location(&self) -> Self::Location {
              Default::default()
        }

        #[inline]
        fn start_state(&self) -> Self::StateIndex {
              0
        }

        #[inline]
        fn token_to_index(&self, token: &Self::Token) -> Option<usize> {
            __token_to_integer(token, core::marker::PhantomData::<()>)
        }

        #[inline]
        fn action(&self, state: i8, integer: usize) -> i8 {
            __action(state, integer)
        }

        #[inline]
        fn error_action(&self, state: i8) -> i8 {
            __action(state, 9 - 1)
        }

        #[inline]
        fn eof_action(&self, state: i8) -> i8 {
            __EOF_ACTION[state as usize]
        }

        #[inline]
        fn goto(&self, state: i8, nt: usize) -> i8 {
            __goto(state, nt)
        }

        fn token_to_symbol(&self, token_index: usize, token: Self::Token) -> Self::Symbol {
            __token_to_symbol(token_index, token, core::marker::PhantomData::<()>)
        }

        fn expected_tokens(&self, state: i8) -> alloc::vec::Vec<alloc::string::String> {
            __expected_tokens(state)
        }

        fn expected_tokens_from_states(&self, states: &[i8]) -> alloc::vec::Vec<alloc::string::String> {
            __expected_tokens_from_states(states, core::marker::PhantomData::<()>)
        }

        #[inline]
        fn uses_error_recovery(&self) -> bool {
            false
        }

        #[inline]
        fn error_recovery_symbol(
            &self,
            recovery: __state_machine::ErrorRecovery<Self>,
        ) -> Self::Symbol {
            panic!("error recovery not enabled for this grammar")
        }

        fn reduce(
            &mut self,
            action: i8,
            start_location: Option<&Self::Location>,
            states: &mut alloc::vec::Vec<i8>,
            symbols: &mut alloc::vec::Vec<__state_machine::SymbolTriple<Self>>,
        ) -> Option<__state_machine::ParseResult<Self>> {
            __reduce(
                action,
                start_location,
                states,
                symbols,
                core::marker::PhantomData::<()>,
            )
        }

        fn simulate_reduce(&self, action: i8) -> __state_machine::SimulatedReduce<Self> {
            __simulate_reduce(action, core::marker::PhantomData::<()>)
        }
    }
    fn __token_to_integer<
    >(
        __token: &lexer::Token,
        _: core::marker::PhantomData<()>,
    ) -> Option<usize>
    {
        match *__token {
            lexer::Token::PublicKey(_) if true => Some(0),
            lexer::Token::PublicSubkey(_) if true => Some(1),
            lexer::Token::SecretKey(_) if true => Some(2),
            lexer::Token::SecretSubkey(_) if true => Some(3),
            lexer::Token::Signature(_) if true => Some(4),
            lexer::Token::Trust(_) if true => Some(5),
            lexer::Token::Unknown(_, _) if true => Some(6),
            lexer::Token::UserID(_) if true => Some(7),
            lexer::Token::UserAttribute(_) if true => Some(8),
            _ => None,
        }
    }
    fn __token_to_symbol<
    >(
        __token_index: usize,
        __token: lexer::Token,
        _: core::marker::PhantomData<()>,
    ) -> __Symbol<>
    {
        #[allow(clippy::manual_range_patterns)]match __token_index {
            0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 => __Symbol::Variant0(__token),
            _ => unreachable!(),
        }
    }
    fn __simulate_reduce<
    >(
        __reduce_index: i8,
        _: core::marker::PhantomData<()>,
    ) -> __state_machine::SimulatedReduce<__StateMachine<>>
    {
        match __reduce_index {
            0 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 2,
                    nonterminal_produced: 0,
                }
            }
            1 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 2,
                    nonterminal_produced: 1,
                }
            }
            2 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 2,
                    nonterminal_produced: 1,
                }
            }
            3 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 2,
                    nonterminal_produced: 1,
                }
            }
            4 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 2,
                    nonterminal_produced: 1,
                }
            }
            5 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 0,
                    nonterminal_produced: 2,
                }
            }
            6 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 2,
                    nonterminal_produced: 2,
                }
            }
            7 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 0,
                    nonterminal_produced: 3,
                }
            }
            8 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 2,
                    nonterminal_produced: 3,
                }
            }
            9 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 2,
                    nonterminal_produced: 3,
                }
            }
            10 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 2,
                    nonterminal_produced: 4,
                }
            }
            11 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 1,
                    nonterminal_produced: 5,
                }
            }
            12 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 1,
                    nonterminal_produced: 5,
                }
            }
            13 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 1,
                    nonterminal_produced: 6,
                }
            }
            14 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 1,
                    nonterminal_produced: 6,
                }
            }
            15 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 1,
                    nonterminal_produced: 7,
                }
            }
            16 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 1,
                    nonterminal_produced: 8,
                }
            }
            17 => {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop: 1,
                    nonterminal_produced: 9,
                }
            }
            18 => __state_machine::SimulatedReduce::Accept,
            _ => panic!("invalid reduction index {}", __reduce_index)
        }
    }
    pub struct CertParser {
        _priv: (),
    }

    impl Default for CertParser { fn default() -> Self { Self::new() } }
    impl CertParser {
        pub fn new() -> CertParser {
            CertParser {
                _priv: (),
            }
        }

        #[allow(dead_code)]
        pub fn parse<
            __TOKEN: __ToTriple<>,
            __TOKENS: IntoIterator<Item=__TOKEN>,
        >(
            &self,
            __tokens0: __TOKENS,
        ) -> Result<Option<Cert>, __lalrpop_util::ParseError<usize, lexer::Token, Error>>
        {
            let __tokens = __tokens0.into_iter();
            let mut __tokens = __tokens.map(|t| __ToTriple::to_triple(t));
            __state_machine::Parser::drive(
                __StateMachine {
                    __phantom: core::marker::PhantomData::<()>,
                },
                __tokens,
            )
        }
    }
    fn __accepts<
    >(
        __error_state: Option<i8>,
        __states: &[i8],
        __opt_integer: Option<usize>,
        _: core::marker::PhantomData<()>,
    ) -> bool
    {
        let mut __states = __states.to_vec();
        __states.extend(__error_state);
        loop {
            let mut __states_len = __states.len();
            let __top = __states[__states_len - 1];
            let __action = match __opt_integer {
                None => __EOF_ACTION[__top as usize],
                Some(__integer) => __action(__top, __integer),
            };
            if __action == 0 { return false; }
            if __action > 0 { return true; }
            let (__to_pop, __nt) = match __simulate_reduce(-(__action + 1), core::marker::PhantomData::<()>) {
                __state_machine::SimulatedReduce::Reduce {
                    states_to_pop, nonterminal_produced
                } => (states_to_pop, nonterminal_produced),
                __state_machine::SimulatedReduce::Accept => return true,
            };
            __states_len -= __to_pop;
            __states.truncate(__states_len);
            let __top = __states[__states_len - 1];
            let __next_state = __goto(__top, __nt);
            __states.push(__next_state);
        }
    }
    fn __reduce<
    >(
        __action: i8,
        __lookahead_start: Option<&usize>,
        __states: &mut alloc::vec::Vec<i8>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> Option<Result<Option<Cert>,__lalrpop_util::ParseError<usize, lexer::Token, Error>>>
    {
        let (__pop_states, __nonterminal) = match __action {
            0 => {
                // Cert = Primary, OptionalComponents => ActionFn(1);
                assert!(__symbols.len() >= 2);
                let __sym1 = __pop_Variant3(__symbols);
                let __sym0 = __pop_Variant5(__symbols);
                let __start = __sym0.0;
                let __end = __sym1.2;
                let __nt = match super::__action1::<>(__sym0, __sym1) {
                    Ok(v) => v,
                    Err(e) => return Some(Err(e)),
                };
                __symbols.push((__start, __Symbol::Variant1(__nt), __end));
                (2, 0)
            }
            1 => {
                __reduce1(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            2 => {
                __reduce2(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            3 => {
                __reduce3(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            4 => {
                __reduce4(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            5 => {
                __reduce5(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            6 => {
                __reduce6(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            7 => {
                __reduce7(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            8 => {
                __reduce8(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            9 => {
                __reduce9(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            10 => {
                __reduce10(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            11 => {
                __reduce11(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            12 => {
                __reduce12(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            13 => {
                __reduce13(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            14 => {
                __reduce14(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            15 => {
                __reduce15(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            16 => {
                __reduce16(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            17 => {
                __reduce17(__lookahead_start, __symbols, core::marker::PhantomData::<()>)
            }
            18 => {
                // __Cert = Cert => ActionFn(0);
                let __sym0 = __pop_Variant1(__symbols);
                let __start = __sym0.0;
                let __end = __sym0.2;
                let __nt = super::__action0::<>(__sym0);
                return Some(Ok(__nt));
            }
            _ => panic!("invalid action code {}", __action)
        };
        let __states_len = __states.len();
        __states.truncate(__states_len - __pop_states);
        let __state = *__states.last().unwrap();
        let __next_state = __goto(__state, __nonterminal);
        __states.push(__next_state);
        None
    }
    #[inline(never)]
    fn __symbol_type_mismatch() -> ! {
        panic!("symbol type mismatch")
    }
    fn __pop_Variant5<
    >(
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>
    ) -> (usize, Option<(Packet, Vec<Signature>)>, usize)
     {
        match __symbols.pop() {
            Some((__l, __Symbol::Variant5(__v), __r)) => (__l, __v, __r),
            _ => __symbol_type_mismatch()
        }
    }
    fn __pop_Variant1<
    >(
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>
    ) -> (usize, Option<Cert>, usize)
     {
        match __symbols.pop() {
            Some((__l, __Symbol::Variant1(__v), __r)) => (__l, __v, __r),
            _ => __symbol_type_mismatch()
        }
    }
    fn __pop_Variant2<
    >(
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>
    ) -> (usize, Option<Component>, usize)
     {
        match __symbols.pop() {
            Some((__l, __Symbol::Variant2(__v), __r)) => (__l, __v, __r),
            _ => __symbol_type_mismatch()
        }
    }
    fn __pop_Variant6<
    >(
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>
    ) -> (usize, Option<Packet>, usize)
     {
        match __symbols.pop() {
            Some((__l, __Symbol::Variant6(__v), __r)) => (__l, __v, __r),
            _ => __symbol_type_mismatch()
        }
    }
    fn __pop_Variant7<
    >(
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>
    ) -> (usize, Option<PacketOrUnknown<Key<key::PublicParts, key::SubordinateRole>>>, usize)
     {
        match __symbols.pop() {
            Some((__l, __Symbol::Variant7(__v), __r)) => (__l, __v, __r),
            _ => __symbol_type_mismatch()
        }
    }
    fn __pop_Variant9<
    >(
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>
    ) -> (usize, Option<PacketOrUnknown<UserAttribute>>, usize)
     {
        match __symbols.pop() {
            Some((__l, __Symbol::Variant9(__v), __r)) => (__l, __v, __r),
            _ => __symbol_type_mismatch()
        }
    }
    fn __pop_Variant10<
    >(
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>
    ) -> (usize, Option<PacketOrUnknown<UserID>>, usize)
     {
        match __symbols.pop() {
            Some((__l, __Symbol::Variant10(__v), __r)) => (__l, __v, __r),
            _ => __symbol_type_mismatch()
        }
    }
    fn __pop_Variant8<
    >(
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>
    ) -> (usize, Option<Unknown>, usize)
     {
        match __symbols.pop() {
            Some((__l, __Symbol::Variant8(__v), __r)) => (__l, __v, __r),
            _ => __symbol_type_mismatch()
        }
    }
    fn __pop_Variant3<
    >(
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>
    ) -> (usize, Option<Vec<Component>>, usize)
     {
        match __symbols.pop() {
            Some((__l, __Symbol::Variant3(__v), __r)) => (__l, __v, __r),
            _ => __symbol_type_mismatch()
        }
    }
    fn __pop_Variant4<
    >(
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>
    ) -> (usize, Option<Vec<Signature>>, usize)
     {
        match __symbols.pop() {
            Some((__l, __Symbol::Variant4(__v), __r)) => (__l, __v, __r),
            _ => __symbol_type_mismatch()
        }
    }
    fn __pop_Variant0<
    >(
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>
    ) -> (usize, lexer::Token, usize)
     {
        match __symbols.pop() {
            Some((__l, __Symbol::Variant0(__v), __r)) => (__l, __v, __r),
            _ => __symbol_type_mismatch()
        }
    }
    fn __reduce1<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // Component = Subkey, OptionalSignatures => ActionFn(10);
        assert!(__symbols.len() >= 2);
        let __sym1 = __pop_Variant4(__symbols);
        let __sym0 = __pop_Variant7(__symbols);
        let __start = __sym0.0;
        let __end = __sym1.2;
        let __nt = super::__action10::<>(__sym0, __sym1);
        __symbols.push((__start, __Symbol::Variant2(__nt), __end));
        (2, 1)
    }
    fn __reduce2<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // Component = UserID, OptionalSignatures => ActionFn(11);
        assert!(__symbols.len() >= 2);
        let __sym1 = __pop_Variant4(__symbols);
        let __sym0 = __pop_Variant10(__symbols);
        let __start = __sym0.0;
        let __end = __sym1.2;
        let __nt = super::__action11::<>(__sym0, __sym1);
        __symbols.push((__start, __Symbol::Variant2(__nt), __end));
        (2, 1)
    }
    fn __reduce3<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // Component = UserAttribute, OptionalSignatures => ActionFn(12);
        assert!(__symbols.len() >= 2);
        let __sym1 = __pop_Variant4(__symbols);
        let __sym0 = __pop_Variant9(__symbols);
        let __start = __sym0.0;
        let __end = __sym1.2;
        let __nt = super::__action12::<>(__sym0, __sym1);
        __symbols.push((__start, __Symbol::Variant2(__nt), __end));
        (2, 1)
    }
    fn __reduce4<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // Component = Unknown, OptionalSignatures => ActionFn(13);
        assert!(__symbols.len() >= 2);
        let __sym1 = __pop_Variant4(__symbols);
        let __sym0 = __pop_Variant8(__symbols);
        let __start = __sym0.0;
        let __end = __sym1.2;
        let __nt = super::__action13::<>(__sym0, __sym1);
        __symbols.push((__start, __Symbol::Variant2(__nt), __end));
        (2, 1)
    }
    fn __reduce5<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // OptionalComponents =  => ActionFn(8);
        let __start = __lookahead_start.cloned().or_else(|| __symbols.last().map(|s| s.2)).unwrap_or_default();
        let __end = __start;
        let __nt = super::__action8::<>(&__start, &__end);
        __symbols.push((__start, __Symbol::Variant3(__nt), __end));
        (0, 2)
    }
    fn __reduce6<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // OptionalComponents = OptionalComponents, Component => ActionFn(9);
        assert!(__symbols.len() >= 2);
        let __sym1 = __pop_Variant2(__symbols);
        let __sym0 = __pop_Variant3(__symbols);
        let __start = __sym0.0;
        let __end = __sym1.2;
        let __nt = super::__action9::<>(__sym0, __sym1);
        __symbols.push((__start, __Symbol::Variant3(__nt), __end));
        (2, 2)
    }
    fn __reduce7<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // OptionalSignatures =  => ActionFn(5);
        let __start = __lookahead_start.cloned().or_else(|| __symbols.last().map(|s| s.2)).unwrap_or_default();
        let __end = __start;
        let __nt = super::__action5::<>(&__start, &__end);
        __symbols.push((__start, __Symbol::Variant4(__nt), __end));
        (0, 3)
    }
    fn __reduce8<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // OptionalSignatures = OptionalSignatures, SIGNATURE => ActionFn(6);
        assert!(__symbols.len() >= 2);
        let __sym1 = __pop_Variant0(__symbols);
        let __sym0 = __pop_Variant4(__symbols);
        let __start = __sym0.0;
        let __end = __sym1.2;
        let __nt = super::__action6::<>(__sym0, __sym1);
        __symbols.push((__start, __Symbol::Variant4(__nt), __end));
        (2, 3)
    }
    fn __reduce9<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // OptionalSignatures = OptionalSignatures, TRUST => ActionFn(7);
        assert!(__symbols.len() >= 2);
        let __sym1 = __pop_Variant0(__symbols);
        let __sym0 = __pop_Variant4(__symbols);
        let __start = __sym0.0;
        let __end = __sym1.2;
        let __nt = super::__action7::<>(__sym0, __sym1);
        __symbols.push((__start, __Symbol::Variant4(__nt), __end));
        (2, 3)
    }
    fn __reduce10<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // Primary = PrimaryKey, OptionalSignatures => ActionFn(2);
        assert!(__symbols.len() >= 2);
        let __sym1 = __pop_Variant4(__symbols);
        let __sym0 = __pop_Variant6(__symbols);
        let __start = __sym0.0;
        let __end = __sym1.2;
        let __nt = super::__action2::<>(__sym0, __sym1);
        __symbols.push((__start, __Symbol::Variant5(__nt), __end));
        (2, 4)
    }
    fn __reduce11<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // PrimaryKey = PUBLIC_KEY => ActionFn(3);
        let __sym0 = __pop_Variant0(__symbols);
        let __start = __sym0.0;
        let __end = __sym0.2;
        let __nt = super::__action3::<>(__sym0);
        __symbols.push((__start, __Symbol::Variant6(__nt), __end));
        (1, 5)
    }
    fn __reduce12<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // PrimaryKey = SECRET_KEY => ActionFn(4);
        let __sym0 = __pop_Variant0(__symbols);
        let __start = __sym0.0;
        let __end = __sym0.2;
        let __nt = super::__action4::<>(__sym0);
        __symbols.push((__start, __Symbol::Variant6(__nt), __end));
        (1, 5)
    }
    fn __reduce13<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // Subkey = PUBLIC_SUBKEY => ActionFn(14);
        let __sym0 = __pop_Variant0(__symbols);
        let __start = __sym0.0;
        let __end = __sym0.2;
        let __nt = super::__action14::<>(__sym0);
        __symbols.push((__start, __Symbol::Variant7(__nt), __end));
        (1, 6)
    }
    fn __reduce14<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // Subkey = SECRET_SUBKEY => ActionFn(15);
        let __sym0 = __pop_Variant0(__symbols);
        let __start = __sym0.0;
        let __end = __sym0.2;
        let __nt = super::__action15::<>(__sym0);
        __symbols.push((__start, __Symbol::Variant7(__nt), __end));
        (1, 6)
    }
    fn __reduce15<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // Unknown = UNKNOWN => ActionFn(18);
        let __sym0 = __pop_Variant0(__symbols);
        let __start = __sym0.0;
        let __end = __sym0.2;
        let __nt = super::__action18::<>(__sym0);
        __symbols.push((__start, __Symbol::Variant8(__nt), __end));
        (1, 7)
    }
    fn __reduce16<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // UserAttribute = USER_ATTRIBUTE => ActionFn(17);
        let __sym0 = __pop_Variant0(__symbols);
        let __start = __sym0.0;
        let __end = __sym0.2;
        let __nt = super::__action17::<>(__sym0);
        __symbols.push((__start, __Symbol::Variant9(__nt), __end));
        (1, 8)
    }
    fn __reduce17<
    >(
        __lookahead_start: Option<&usize>,
        __symbols: &mut alloc::vec::Vec<(usize,__Symbol<>,usize)>,
        _: core::marker::PhantomData<()>,
    ) -> (usize, usize)
    {
        // UserID = USERID => ActionFn(16);
        let __sym0 = __pop_Variant0(__symbols);
        let __start = __sym0.0;
        let __end = __sym0.2;
        let __nt = super::__action16::<>(__sym0);
        __symbols.push((__start, __Symbol::Variant10(__nt), __end));
        (1, 9)
    }
}
#[allow(unused_imports)]
pub use self::__parse__Cert::CertParser;

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action0<
>(
    (_, __0, _): (usize, Option<Cert>, usize),
) -> Option<Cert>
{
    __0
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action1<
>(
    (_, p, _): (usize, Option<(Packet, Vec<Signature>)>, usize),
    (_, c, _): (usize, Option<Vec<Component>>, usize),
) -> Result<Option<Cert>,__lalrpop_util::ParseError<usize,lexer::Token,Error>>
{
    {
        match p {
            Some((Packet::PublicKey(_), _))
            | Some((Packet::SecretKey(_), _)) => {
                let (key, sigs) = match p {
                    Some((Packet::PublicKey(key), sigs)) => (key, sigs),
                    Some((Packet::SecretKey(key), sigs)) => (key.into(), sigs),
                    _ => unreachable!(),
                };
                let c = c.unwrap();
                let sec = key.hash_algo_security();

                let pk = Arc::new(key.clone().take_secret().0);
                let mut cert = Cert {
                    primary: PrimaryKeyBundle::new(key, sec, sigs)
                        .with_context(pk.clone()),
                    subkeys: ComponentBundles::default(),
                    userids: ComponentBundles::default(),
                    user_attributes: ComponentBundles::default(),
                    unknowns: ComponentBundles::default(),
                    bad: vec![],
                };

                for c in c.into_iter() {
                    match c {
                        Component::SubkeyBundle(b) =>
                            cert.subkeys.push(b.with_subkey_context(pk.clone())),
                        Component::UserIDBundle(b) =>
                            cert.userids.push(b.with_context(pk.clone())),
                        Component::UserAttributeBundle(b) =>
                            cert.user_attributes.push(b.with_context(pk.clone())),
                        Component::UnknownBundle(b) =>
                            cert.unknowns.push(b.with_context(pk.clone())),
                    }
                }

                Ok(Some(cert))
            }
            Some((Packet::Unknown(unknown), sigs)) => {
                let msg = unknown.error().to_string();
                let mut packets: Vec<Packet> = Default::default();
                packets.push(unknown.into());
                for sig in sigs {
                    packets.push(sig.into());
                }
                for c in c.unwrap_or_default().into_iter() {
                    match c {
                        Component::SubkeyBundle(b) =>
                            b.into_packets().for_each(|p| packets.push(p)),
                        Component::UserIDBundle(b) =>
                            b.into_packets().for_each(|p| packets.push(p)),
                        Component::UserAttributeBundle(b) =>
                            b.into_packets().for_each(|p| packets.push(p)),
                        Component::UnknownBundle(b) =>
                            b.into_packets().for_each(|p| packets.push(p)),
                    }
                }
                Err(ParseError::User {
                    error: Error::UnsupportedCert2(
                        format!("Unsupported primary key: {}", msg),
                        packets),
                })
            }
            None => {
                // Just validating a cert...
                assert!(c.is_none() || c.unwrap().len() == 0);
                Ok(None)
            }
            Some((pkt, _)) =>
              unreachable!("Expected key or unknown packet, got {:?}", pkt),
        }
    }
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action2<
>(
    (_, pk, _): (usize, Option<Packet>, usize),
    (_, sigs, _): (usize, Option<Vec<Signature>>, usize),
) -> Option<(Packet, Vec<Signature>)>
{
    {
        if let Some(pk) = pk {
            Some((pk, sigs.unwrap()))
        } else {
            // Just validating a cert...
            assert!(sigs.is_none() || sigs.unwrap().len() == 0);
            None
        }
    }
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action3<
>(
    (_, t, _): (usize, lexer::Token, usize),
) -> Option<Packet>
{
    t.into()
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action4<
>(
    (_, t, _): (usize, lexer::Token, usize),
) -> Option<Packet>
{
    t.into()
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action5<
>(
    __lookbehind: &usize,
    __lookahead: &usize,
) -> Option<Vec<Signature>>
{
    Some(vec![])
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action6<
>(
    (_, sigs, _): (usize, Option<Vec<Signature>>, usize),
    (_, sig, _): (usize, lexer::Token, usize),
) -> Option<Vec<Signature>>
{
    {
        match sig {
            Token::Signature(Some(Packet::Signature(sig))) => {
                assert!(sigs.is_some());
                let mut sigs = sigs.unwrap();

                sigs.push(sig);
                Some(sigs)
            }
            Token::Signature(Some(Packet::Unknown(_sig))) => {
                // Ignore unsupported / bad signatures.
                assert!(sigs.is_some());
                sigs
            }
            // Just validating a cert...
            Token::Signature(None) => return None,
            tok => unreachable!("Expected signature token, got {:?}", tok),
        }
    }
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action7<
>(
    (_, __0, _): (usize, Option<Vec<Signature>>, usize),
    (_, _, _): (usize, lexer::Token, usize),
) -> Option<Vec<Signature>>
{
    __0
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action8<
>(
    __lookbehind: &usize,
    __lookahead: &usize,
) -> Option<Vec<Component>>
{
    Some(vec![])
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action9<
>(
    (_, cs, _): (usize, Option<Vec<Component>>, usize),
    (_, c, _): (usize, Option<Component>, usize),
) -> Option<Vec<Component>>
{
    {
        if let Some(c) = c {
            let mut cs = cs.unwrap();
            cs.push(c);
            Some(cs)
        } else {
            // Just validating a cert...
            None
        }
    }
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action10<
>(
    (_, key, _): (usize, Option<PacketOrUnknown<Key<key::PublicParts, key::SubordinateRole>>>, usize),
    (_, sigs, _): (usize, Option<Vec<Signature>>, usize),
) -> Option<Component>
{
    {
        match key {
            Some(Ok(key)) => {
                let sigs = sigs.unwrap();
                let sec = key.hash_algo_security();

                Some(Component::SubkeyBundle(
                    SubkeyBundle::new(key, sec, sigs)))
            },
            Some(Err(u)) => Some(Component::UnknownBundle(
                UnknownBundle::new(u, CollisionResistance,
                                   sigs.unwrap_or_default()))),
            // Just validating a cert...
            None => None,
        }
    }
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action11<
>(
    (_, u, _): (usize, Option<PacketOrUnknown<UserID>>, usize),
    (_, sigs, _): (usize, Option<Vec<Signature>>, usize),
) -> Option<Component>
{
    {
        match u {
            Some(Ok(u)) => {
                let sigs = sigs.unwrap();
                let sec = u.hash_algo_security();

                Some(Component::UserIDBundle(
                    UserIDBundle::new(u, sec, sigs)))
            },
            Some(Err(u)) => Some(Component::UnknownBundle(
                UnknownBundle::new(u, CollisionResistance,
                                   sigs.unwrap_or_default()))),
            // Just validating a cert...
            None => None,
        }
    }
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action12<
>(
    (_, u, _): (usize, Option<PacketOrUnknown<UserAttribute>>, usize),
    (_, sigs, _): (usize, Option<Vec<Signature>>, usize),
) -> Option<Component>
{
    {
        match u {
            Some(Ok(u)) => {
                let sigs = sigs.unwrap();
                let sec = u.hash_algo_security();

                Some(Component::UserAttributeBundle(
                    UserAttributeBundle::new(u, sec, sigs)))
            },
            Some(Err(u)) => Some(Component::UnknownBundle(
                UnknownBundle::new(u, CollisionResistance,
                                   sigs.unwrap_or_default()))),
            // Just validating a cert...
            None => None,
        }
    }
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action13<
>(
    (_, u, _): (usize, Option<Unknown>, usize),
    (_, sigs, _): (usize, Option<Vec<Signature>>, usize),
) -> Option<Component>
{
    {
        match u {
            Some(u) => {
                let sigs = sigs.unwrap();
                let sec = u.hash_algo_security();

                Some(Component::UnknownBundle(
                    UnknownBundle::new(u, sec, sigs)))
            },
            // Just validating a cert...
            None => None,
        }
    }
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action14<
>(
    (_, t, _): (usize, lexer::Token, usize),
) -> Option<PacketOrUnknown<Key<key::PublicParts, key::SubordinateRole>>>
{
    {
        match Option::<Packet>::from(t) {
            Some(p) => Some(p.downcast().map_err(
                |p| p.try_into().expect("infallible for unknown and this packet"))),
            // Just validating a cert...
            None => None,
        }
    }
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action15<
>(
    (_, t, _): (usize, lexer::Token, usize),
) -> Option<PacketOrUnknown<Key<key::PublicParts, key::SubordinateRole>>>
{
    {
        match Option::<Packet>::from(t) {
            Some(p) => Some(Any::<key::SecretSubkey>::downcast(p)
                .map_err(
                    |p| p.try_into().expect("infallible for unknown and this packet"))
                .map(|sk| sk.parts_into_public())),
            // Just validating a cert...
            None => None,
        }
    }
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action16<
>(
    (_, t, _): (usize, lexer::Token, usize),
) -> Option<PacketOrUnknown<UserID>>
{
    {
        match Option::<Packet>::from(t) {
            Some(p) => Some(p.downcast().map_err(
                |p| p.try_into().expect("infallible for unknown and this packet"))),
            // Just validating a cert...
            None => None,
        }
    }
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action17<
>(
    (_, t, _): (usize, lexer::Token, usize),
) -> Option<PacketOrUnknown<UserAttribute>>
{
    {
        match Option::<Packet>::from(t) {
            Some(p) => Some(p.downcast().map_err(
                |p| p.try_into().expect("infallible for unknown and this packet"))),
            // Just validating a cert...
            None => None,
        }
    }
}

#[allow(clippy::too_many_arguments, clippy::needless_lifetimes, clippy::just_underscores_and_digits)]
fn __action18<
>(
    (_, t, _): (usize, lexer::Token, usize),
) -> Option<Unknown>
{
    {
        match Option::<Packet>::from(t) {
            Some(p) => p.try_into().ok(),
            // Just validating a cert...
            None => None,
        }
    }
}
#[allow(clippy::type_complexity, dead_code)]

pub  trait __ToTriple<>
{
    fn to_triple(value: Self) -> Result<(usize,lexer::Token,usize), __lalrpop_util::ParseError<usize, lexer::Token, Error>>;
}

impl<> __ToTriple<> for (usize, lexer::Token, usize)
{
    fn to_triple(value: Self) -> Result<(usize,lexer::Token,usize), __lalrpop_util::ParseError<usize, lexer::Token, Error>> {
        Ok(value)
    }
}
impl<> __ToTriple<> for Result<(usize, lexer::Token, usize), Error>
{
    fn to_triple(value: Self) -> Result<(usize,lexer::Token,usize), __lalrpop_util::ParseError<usize, lexer::Token, Error>> {
        match value {
            Ok(v) => Ok(v),
            Err(error) => Err(__lalrpop_util::ParseError::User { error }),
        }
    }
}
