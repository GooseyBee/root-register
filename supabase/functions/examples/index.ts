// 사용 중지된 함수. 요금이 나오지 않도록 AI(Claude API) 호출을 모두 뺐다 (2026-09-25).
// 예문과 설명은 이제 데이터로 미리 넣어 둔다. 대시보드에서 함수를 삭제해도 된다.
Deno.serve(() =>
  new Response(JSON.stringify({ error: "disabled" }), {
    status: 410,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  })
);
