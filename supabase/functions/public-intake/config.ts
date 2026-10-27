export function isSupabaseUrl(value: string | undefined): value is string {
  if (value === undefined || value.length === 0) return false;
  try {
    const url = new URL(value);
    const hostname = url.hostname;
    const ipv4 = hostname.split(".");
    const isLoopbackIpv4 = ipv4.length === 4 && ipv4[0] === "127" &&
      ipv4.every((part) =>
        /^(0|[1-9][0-9]{0,2})$/.test(part) &&
        Number(part) <= 255
      );
    const isLoopbackHttp = url.protocol === "http:" &&
      (hostname === "localhost" || hostname === "[::1]" || isLoopbackIpv4);
    return (url.protocol === "https:" || isLoopbackHttp) &&
      url.username.length === 0 && url.password.length === 0 &&
      url.pathname === "/" && url.search.length === 0 && url.hash.length === 0;
  } catch {
    return false;
  }
}
