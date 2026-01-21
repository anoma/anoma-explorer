defmodule AnomaExplorerWeb.PageControllerTest do
  use AnomaExplorerWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Dashboard"
    assert html =~ "Activity Feed"
    assert html =~ "Analytics"
  end
end
