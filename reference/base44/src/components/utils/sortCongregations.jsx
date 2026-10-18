/**
 * Sort congregations with Sede first, then alphabetically
 */
export function sortCongregations(congregations) {
  return [...congregations].sort((a, b) => {
    const aIsSede = a.name.toLowerCase().includes('sede');
    const bIsSede = b.name.toLowerCase().includes('sede');
    
    if (aIsSede && !bIsSede) return -1;
    if (!aIsSede && bIsSede) return 1;
    
    return a.name.localeCompare(b.name, 'pt-BR');
  });
}

/**
 * Sort converts by congregation
 */
export function sortConvertsByCongregation(converts, congregations) {
  return [...converts].sort((a, b) => {
    const congA = congregations.find(c => c.id === a.congregation_id);
    const congB = congregations.find(c => c.id === b.congregation_id);
    
    if (!congA && !congB) return 0;
    if (!congA) return 1;
    if (!congB) return -1;
    
    const aIsSede = congA.name.toLowerCase().includes('sede');
    const bIsSede = congB.name.toLowerCase().includes('sede');
    
    if (aIsSede && !bIsSede) return -1;
    if (!aIsSede && bIsSede) return 1;
    
    return congA.name.localeCompare(congB.name, 'pt-BR');
  });
}