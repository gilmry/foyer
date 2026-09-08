"""Schémas Pydantic — désérialisation stricte (extra='forbid' = deny_unknown_fields, gate contrat)."""
from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class TodoCreateInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    title: str


class TodoView(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: str
    title: str
    done: bool
    createdAt: str
    updatedAt: str


class TodoList(BaseModel):
    items: list[TodoView]


class DeleteResult(BaseModel):
    deleted: bool


class ErrorList(BaseModel):
    errors: list[str]


class Error(BaseModel):
    error: str
