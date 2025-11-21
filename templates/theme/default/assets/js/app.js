(() => {
  const el = document.querySelector('[data-build-info]')
  if (!el) return
  const time = new Date().toLocaleString()
  el.textContent = `Built at ${time}`
})()
