import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  try {
    // Initialize Supabase client with service role key
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    
    // Get current timestamp
    const now = new Date()
    const revealThreshold = new Date(now.getTime() - (24 * 60 * 60 * 1000)) // 24 hours ago
    
    console.log(`🕐 Checking for events to reveal...`)
    console.log(`📅 Current time: ${now.toISOString()}`)
    console.log(`⏰ Reveal threshold: ${revealThreshold.toISOString()}`)
    
    // Find events that should be revealed:
    // - release_at was more than 24 hours ago
    // - is_revealed is still false
    const { data: eventsToReveal, error: fetchError } = await supabase
      .from('events')
      .select('id, title, release_at, is_revealed')
      .lte('release_at', revealThreshold.toISOString())
      .eq('is_revealed', false)
    
    if (fetchError) {
      console.error('❌ Error fetching events:', fetchError)
      throw fetchError
    }
    
    console.log(`📸 Found ${eventsToReveal?.length || 0} events ready to reveal`)
    
    // Update each event to revealed status
    if (eventsToReveal && eventsToReveal.length > 0) {
      const eventIds = eventsToReveal.map(e => e.id)
      
      const { data: updatedEvents, error: updateError } = await supabase
        .from('events')
        .update({ is_revealed: true })
        .in('id', eventIds)
        .select()
      
      if (updateError) {
        console.error('❌ Error updating events:', updateError)
        throw updateError
      }
      
      console.log(`✅ Successfully revealed ${updatedEvents?.length || 0} events`)
      
      // Log each revealed event
      updatedEvents?.forEach(event => {
        console.log(`  📸 Revealed: "${event.title}" (${event.id})`)
      })
      
      return new Response(
        JSON.stringify({
          success: true,
          message: `Revealed ${updatedEvents?.length || 0} events`,
          revealed_count: updatedEvents?.length || 0,
          events: updatedEvents
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    } else {
      console.log(`ℹ️ No events ready to reveal at this time`)
      
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No events ready to reveal',
          revealed_count: 0
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }
    
  } catch (error) {
    console.error('💥 Fatal error:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Unknown error occurred'
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
})

