###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
     at your option any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###

define
  titles:
    itemType: "Type d'objets %s"
    eventType: "Type d'évènements %s"
    fieldType: 'Type de terrains %s'
    rule: 'Règle'
    turnRule: 'Règle de tour'
    map: 'Carte %s'
    removeConfirm: 'Suppression'
    closeConfirm: 'Fermeture'
    external: 'Modification externe'
    categories:
      items: 'Objets'
      maps: 'Cartes'
      events: 'Evènements'
      rules: 'Règles'
      turnRules: 'Règles de tour'
      fields: 'Terrains'
    multipleAffectation: 'Affectation multiple'

  msgs:
    removeItemTypeConfirm: "<p>Voulez-vous vraiment supprimer le type d'object <b>%s</b> ?</p><p>Tous les objets de ce type seront aussi supprimés.</p>"
    removeFieldTypeConfirm: "<p>Voulez-vous vraiment supprimer le type de terrains <b>%s</b> ?</p><p>Tous les terrains de ce type seront aussi supprimés.</p>"
    removeRuleConfirm: "<p>Voulez-vous vraiment supprimer la règle <b>%s</b> ?</p>"
    removeMapConfirm: "<p>Voulez-vous vraiment supprimer la carte <b>%s</b> ?</p><p>Tous les terrains et les objets sur cette carte seront aussi supprimés.</p>"
    closeConfirm: "<p>Vous avez modifié <b>%s</b>.</p><p>Voulez-vous sauver les modifications avant de fermer l'onglet ?</p>"
    externalChange: "<p><b>%s</b> a été modifié par un autre administrateur.</p><p>Ses valeurs ont été mises à jour.</p>"
    externalRemove: "<p><b>%s</b> a été supprimé par un autre administrateur.</p><p>L'onglet va être fermé.</p>"
    invalidUidError: 'les uid de propriétés ne peuvent commencer que par des caractères alphabétiques ou $ et _'
    invalidExecutableNameError: "le nom d'un executable ne peut contenir que des caractères alphanumeriques"
    saveFailed: "<p><b>%1s</b> n'a pas pû être sauvé sur le serveur :</p><p>%2s</p>" 
    removeFailed: "<p><b>%1s</b> n'a pas pû être supprimé du serveur :</p><p>%2s</p>"
    multipleAffectation: 'Choisisez les images que vous aller affecter dans la séléction (l\'ordre est significatif)'

  buttons:
    'new': 'Nouveau...'
    newItemType: "Type d'objets"
    newFieldType: 'Type de terrains'
    newRule: 'Règle'
    newTurnRule: 'Règle de tour'
    newMap: 'Carte'
    newEventType: "Type d'évènements"

  labels:
    yes: 'Oui'
    no: 'Non'
    ok: 'Ok'
    cancel: 'Annuler'
    newType: '(nouveau)'
    descImage: 'Type'
    images: 'Instances'
    category: 'Catégorie'
    rank: 'Rang'
    fieldSeparator: ' : '
    name: 'Nom'
    desc: 'Description'
    newName: 'A remplir'
    quantifiable: 'Quantifiable'
    noRuleCategory: 'aucune'
    propertyUidField: 'Uid'
    properties: 'Propriétés'
    propertyUid: 'Uid (unique)'
    propertyType: 'Type'
    propertyValue: 'Valeur par défaut'
    propertyDefaultName: 'todo'
    propertyTypes:
      string: 'chaîne de caractères'
      text: 'texte'
      boolean: 'booléen'
      float: 'réel'
      integer: 'entier'
      date: 'date'
      object: 'objet'
      array: "tableau d'objets"
    mapKind: 'Type'
    mapKinds: [
      {name: '2D-iso hexagonale', value:'hexagon'}
      {name: '2D-iso carrée', value:'diamond'}
      {name: '2D carrée', value:'square'}
    ]
    randomAffect: 'affectation aléatoire'
    zoom: 'Zoom'
    gridShown: 'Grille'
    markersShown: 'Graduation'

  tips:
    save: "Enregistrer l'onglet en cours d'édition"
    remove: "Supprimer l'onglet en cours d'édition"
    addProperty: 'Ajoute une nouvelle propriété'
    removeSelection: 'Supprime la séléction courante de la carte éditée'
    description: 'TODO description'