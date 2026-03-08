"""
Pytest configuration for all tests.

This conftest file sets up the environment before any tests are collected.
It handles database mocking for tests that don't need a real database.
"""

import os
import sys

# Set environment variables before any imports
os.environ.setdefault("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/test_coachingapp")
os.environ.setdefault("JWT_SECRET", "test-secret-key-for-integration-tests")
os.environ.setdefault("ANTHROPIC_API_KEY", "sk-ant-test-key")


def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers", "requires_db: mark test as requiring a real database connection"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow running"
    )
