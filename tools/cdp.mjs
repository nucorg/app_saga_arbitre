// Client Chrome DevTools Protocol, sans dépendance npm (Node >= 22).
export async function connect(port = 9347) {
  const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  const target = targets.find(t => t.type === 'page');
  if (!target) throw Error('Aucun onglet Chrome');
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((ok, no) => { ws.onopen = ok; ws.onerror = no; });
  let id = 0;
  const pending = new Map();
  ws.onmessage = ({data}) => {
    const msg = JSON.parse(data);
    if (!pending.has(msg.id)) return;
    const {ok, no, timer} = pending.get(msg.id);
    clearTimeout(timer); pending.delete(msg.id);
    msg.error ? no(Error(JSON.stringify(msg.error))) : ok(msg.result);
  };
  const call = (method, params = {}) => new Promise((ok, no) => {
    const key = ++id;
    const timer = setTimeout(() => { pending.delete(key); no(Error(`Délai dépassé : ${method}`)); }, 20000);
    pending.set(key, {ok, no, timer});
    ws.send(JSON.stringify({id: key, method, params}));
  });
  const evaluate = async expression => {
    const r = await call('Runtime.evaluate', {expression, returnByValue: true, awaitPromise: true});
    if (r.exceptionDetails) throw Error(JSON.stringify(r.exceptionDetails));
    return r.result.value;
  };
  const until = async expression => {
    for (let n = 0; n < 120; n++) {
      if (await evaluate(expression)) return;
      await new Promise(r => setTimeout(r, 250));
    }
    throw Error(`Condition non atteinte : ${expression}`);
  };
  return {call, evaluate, until, close: () => ws.close()};
}
