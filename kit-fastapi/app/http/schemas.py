"""Schémas Pydantic — désérialisation stricte (extra='forbid' = deny_unknown_fields, gate contrat).
Aucun schéma d'entrée ne porte de propriétaire : il vient de l'identité, jamais de la requête."""
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


class CredentialsInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    email: str
    password: str


class AccountView(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: str
    email: str


class TokenView(BaseModel):
    model_config = ConfigDict(extra="forbid")
    token: str
    tokenType: str
    expiresAt: str


class LogoutResult(BaseModel):
    loggedOut: bool


class Health(BaseModel):
    status: str
