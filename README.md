# YOUNES CRM — version avec MS HOUSE BARBER

Interface CRM bilingue (Français / العربية), thème clair. Connexion Supabase par identifiant interne `username@younes-crm.internal`; le navigateur utilise uniquement la clé publishable.

## Modules de cette version
- Dashboard et gestion existante : Contacts, Entreprises, Opportunités, Tâches, Notes.
- Commandes HERMANO : synchronisation manuelle via l'Edge Function `crm-hermano-sync` et mise à jour des statuts.
- MS HOUSE BARBER : gestion des barbiers, services, rendez-vous et paiement direct au barbier.
- `booking.html` : formulaire public de demande de rendez-vous pour le site du salon.

## Configuration
- Supabase project: `axmtmljpdwmpsclxzldt`
- URL: `https://axmtmljpdwmpsclxzldt.supabase.co`
- Le schéma MS HOUSE BARBER et les règles RLS ont été appliqués le 27 novembre 2026.
- Tenant: `ms-house-barber`.
- Aucun service-role ou secret de bridge n'est présent dans le frontend.

## Déploiement
1. Héberger `index.html` et `booking.html` sur un hébergement HTTPS statique.
2. Le bouton `Page de réservation` ouvre `booking.html`.
3. Pour publier sur GitHub Pages, placer les deux fichiers dans la racine du dépôt du CRM.
4. Après le déploiement, ajouter les barbiers et les services depuis le menu `MS HOUSE BARBER`. Le formulaire public affichera les éléments actifs.
5. Les demandes externes arrivent avec le statut `pending`; le salon doit confirmer le créneau. Une protection côté base refuse les chevauchements pour un même barbier.

## Rémunération
Chaque service possède un prix client et un montant fixe pour le barbier. Le montant revenant au salon est calculé en base (`salon_share = price - barber_fixed_fee`). Le paiement est enregistré comme reçu directement par le barbier.

## HERMANO
La page `Commandes HERMANO` appelle `crm-hermano-sync`. Elle suppose que les Edge Functions et secrets configurés précédemment restent actifs. La synchronisation doit être testée avec une vraie session Admin.

## À compléter / valider
- OY ACCESSOIRES n'est pas encore branché dans l'interface.
- Les nouveaux utilisateurs employés doivent être créés dans Supabase Auth avec les `app_metadata` et `crm_profiles.tenant_id` appropriés avant leur connexion.
- Configurer les prix, commissions fixes, horaires et coordonnées réels du salon.
- Vérifier le domaine public et le canal de confirmation (appel/WhatsApp) avant d'annoncer la réservation en ligne.
