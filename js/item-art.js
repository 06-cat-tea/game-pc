(() => {
  'use strict';
  const fallback=id=>GameData.ITEMS[id]?.slot==='armor'?'warden':GameData.ITEMS[id]?.slot==='charm'?'affinity':'equipment';
  function icon(id,size=''){
    const e=ArtCatalog.equipment?.[id],it=GameData.ITEMS[id];if(!e||!it)return UIIcons.icon(fallback(id));
    return '<span class="item-art rarity-'+it.rarity+' '+size+'" aria-hidden="true"><img data-item-art="'+id+'" src="'+WorldAssets.path('equipment',id)+'" alt="" loading="lazy" draggable="false"></span>';
  }
  // A missing icon never removes an item's name, stats or actions.
  document.addEventListener('error',event=>{const image=event.target;if(!image.matches?.('img[data-item-art]')||image.dataset.itemFallback)return;image.dataset.itemFallback='true';image.src='assets/icons/rail/'+fallback(image.dataset.itemArt)+'.svg';},true);
  window.ItemArt={icon};
})();
