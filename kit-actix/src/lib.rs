//! Kit Foyer Rust — architecture hexagonale.
//! `domain` et `application` sont du **Rust pur** (std uniquement) ; actix (HTTP) et sqlx
//! (persistance) vivent exclusivement dans `adapter`/`http`. Vérifié par le gate H1.
#![allow(async_fn_in_trait)]

pub mod adapter;
pub mod application;
pub mod domain;
pub mod http;
