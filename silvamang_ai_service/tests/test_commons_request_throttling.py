from __future__ import annotations

from urllib.error import HTTPError

import pytest

from scripts import collect_unknown_commons_candidates as unknown_collector
from scripts import collect_commons_part_candidates as commons


def _http_error(retry_after: str) -> HTTPError:
    return HTTPError(
        "https://upload.wikimedia.org/example.jpg",
        429,
        "Too Many Requests",
        {"Retry-After": retry_after},
        None,
    )


def test_unknown_search_requests_standard_800px_thumbnail(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    requests: list[dict[str, object]] = []

    def fake_request(params: dict[str, object]) -> dict[str, object]:
        requests.append(params)
        return {"query": {"pages": []}}

    monkeypatch.setattr(unknown_collector, "request_json", fake_request)

    assert list(unknown_collector.commons_pages("coconut", 1)) == []
    assert requests[0]["iiurlwidth"] == commons.COMMONS_THUMBNAIL_WIDTH == 800


def test_image_download_honors_short_retry_after(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls = 0
    delays: list[float] = []

    def fake_download(_url: str) -> tuple[bytes, str]:
        nonlocal calls
        calls += 1
        if calls == 1:
            raise _http_error("10")
        return b"image", ".jpg"

    monkeypatch.setattr(commons, "download_image", fake_download)
    monkeypatch.setattr(commons, "wait_for_download_slot", lambda: None)
    monkeypatch.setattr(commons.time, "sleep", delays.append)

    assert commons.download_commons_image("https://example.test/image.jpg") == (
        b"image",
        ".jpg",
    )
    assert calls == 2
    assert delays == [10.0]


def test_image_download_stops_on_long_retry_after_without_sleeping_or_retrying(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls = 0
    delays: list[float] = []

    def rate_limited(_url: str) -> tuple[bytes, str]:
        nonlocal calls
        calls += 1
        raise _http_error("600")

    monkeypatch.setattr(commons, "download_image", rate_limited)
    monkeypatch.setattr(commons, "wait_for_download_slot", lambda: None)
    monkeypatch.setattr(commons.time, "sleep", delays.append)

    with pytest.raises(commons.CommonsCooldownError, match=r"600s.*resume") as caught:
        commons.download_commons_image("https://example.test/image.jpg")

    assert caught.value.retry_after_seconds == 600.0
    assert calls == 1
    assert delays == []


def test_download_slot_enforces_four_second_spacing(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    times = iter((102.0, 104.0))
    delays: list[float] = []
    monkeypatch.setattr(commons.time, "monotonic", lambda: next(times))
    monkeypatch.setattr(commons.time, "sleep", delays.append)
    monkeypatch.setattr(commons, "_last_download_at", 100.0)

    commons.wait_for_download_slot()

    assert commons.IMAGE_DOWNLOAD_DELAY_SECONDS == 4.0
    assert delays == [2.0]
    assert commons._last_download_at == 104.0
