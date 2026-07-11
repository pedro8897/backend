var getStore = require("@netlify/blobs").getStore;

function resposta(statusCode, dados) {
  return {
    statusCode: statusCode,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "GET, POST, PATCH, DELETE, OPTIONS",
      "access-control-allow-headers": "content-type"
    },
    body: JSON.stringify(dados)
  };
}

function pedidosStore() {
  return getStore("kintsugi-pedidos");
}

async function lerPedidos() {
  return await pedidosStore().get("lista", { type: "json" }) || [];
}

async function salvarPedidos(pedidos) {
  await pedidosStore().setJSON("lista", pedidos);
}

exports.handler = async function (event) {
  if (event.httpMethod === "OPTIONS") {
    return resposta(200, { ok: true });
  }

  if (event.httpMethod === "GET") {
    var listaGet = await lerPedidos();
    return resposta(200, {
      ok: true,
      total: listaGet.length,
      pedidos: listaGet
    });
  }

  if (event.httpMethod === "POST") {
    var dados = JSON.parse(event.body || "{}");
    var listaPost = await lerPedidos();
    var pedido = {
      id: "PED-" + Date.now(),
      code: dados.code || dados.codigo || "",
      criadoEm: new Date().toISOString(),
      cliente: dados.cliente || "",
      telefone: dados.telefone || "",
      itens: dados.itens || [],
      total: dados.total || "",
      pagamento: dados.pagamento || "",
      endereco: dados.endereco || "",
      step: 0
    };

    listaPost.unshift(pedido);
    await salvarPedidos(listaPost);

    return resposta(201, {
      ok: true,
      mensagem: "Pedido recebido",
      pedido: pedido
    });
  }

  if (event.httpMethod === "PATCH") {
    var atualizacao = JSON.parse(event.body || "{}");
    var step = Number(atualizacao.step);
    if (!Number.isFinite(step) || step < 0 || step > 3) {
      return resposta(400, {
        ok: false,
        erro: "Status invalido"
      });
    }

    var listaPatch = await lerPedidos();
    var pedidoEncontrado = listaPatch.find(function (pedido) {
      return pedido.id === atualizacao.id || pedido.code === atualizacao.code;
    });

    if (!pedidoEncontrado) {
      return resposta(404, {
        ok: false,
        erro: "Pedido nao encontrado"
      });
    }

    pedidoEncontrado.step = step;
    pedidoEncontrado.atualizadoEm = new Date().toISOString();
    await salvarPedidos(listaPatch);

    return resposta(200, {
      ok: true,
      mensagem: "Status atualizado",
      pedido: pedidoEncontrado
    });
  }

  if (event.httpMethod === "DELETE") {
    await salvarPedidos([]);
    return resposta(200, {
      ok: true,
      mensagem: "Historico limpo"
    });
  }

  return resposta(405, {
    ok: false,
    erro: "Metodo nao permitido"
  });
};

