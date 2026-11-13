# Ajustes necessários no projeto frontend real

No `~/Desktop/TCC/projeto-frontend/Dockerfile`, antes de `RUN npm run build`, garantir:

```dockerfile
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL
```

O `src/utils/api.js` já utiliza `import.meta.env.VITE_API_URL || 'http://localhost:8080'`. Para a nuvem, `VITE_API_URL` precisa ser preenchida **no docker build** com o endpoint HTTPS real do backend.

Verifique também se o Dockerfile preserva:
```dockerfile
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
```
E se `nginx.conf` contém o fallback para rotas do React Router:
```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

**Não execute automaticamente `git stash pop` nem substitua o Dockerfile existente.** Compare com as alterações locais atuais antes de editar.

No backend real, o CORS local foi corrigido. Para a AWS, limite `allowedOrigins` aos domínios públicos HTTPS do HelpTech e confirme a compatibilidade dos endpoints OAuth/JWT.
